#include "Shaders.hlsl"

#define PARTICLE_TYPE_EMITTER		0
#define PARTICLE_TYPE_SHELL			1
#define PARTICLE_TYPE_FLARE01		2
#define PARTICLE_TYPE_FLARE02		3
#define PARTICLE_TYPE_FLARE03		4

#define SHELL_PARTICLE_LIFETIME		1.0f
#define FLARE01_PARTICLE_LIFETIME	5.0f
#define FLARE02_PARTICLE_LIFETIME	3.0f
#define FLARE03_PARTICLE_LIFETIME	0.25f

struct VS_PARTICLE_INPUT
{
	float3 position : POSITION;
	float3 velocity : VELOCITY;
	float lifetime : LIFETIME;
	uint type : PARTICLETYPE;
};

VS_PARTICLE_INPUT VSParticleStreamOutput(VS_PARTICLE_INPUT input)
{
	return(input);
}

float3 GetParticleColor(float fAge, float fLifetime)
{
	float3 cColor = float3(1.0f, 1.0f, 1.0f);

	if (fAge == 0.0f) 
		cColor = float3(0.0f, 1.0f, 0.0f);
	else if (fLifetime == 0.0f)
		cColor = float3(1.0f, 1.0f, 0.0f);
	else
	{
		float t = fAge / fLifetime;
		cColor = lerp(float3(1.0f, 0.0f, 0.0f), float3(0.0f, 0.0f, 1.0f), t * 1.0f);
	}

	return(cColor);
}

void GetBillboardCorners(float3 position, float2 size, out float4 pf4Positions[4])
{
	float3 f3Up = float3(0.0f, 1.0f, 0.0f);
	float3 f3Look = normalize(gvCameraPosition - position);
	float3 f3Right = normalize(cross(f3Up, f3Look));

	pf4Positions[0] = float4(position + size.x * f3Right - size.y * f3Up, 1.0f);
	pf4Positions[1] = float4(position + size.x * f3Right + size.y * f3Up, 1.0f);
	pf4Positions[2] = float4(position - size.x * f3Right - size.y * f3Up, 1.0f);
	pf4Positions[3] = float4(position - size.x * f3Right + size.y * f3Up, 1.0f);
}

void GetPositions(float3 position, float2 f2Size, out float3 pf3Positions[8])
{
	float3 f3Right = float3(1.0f, 0.0f, 0.0f);
	float3 f3Up = float3(0.0f, 1.0f, 0.0f);
	float3 f3Look = float3(0.0f, 0.0f, 1.0f);

	float3 f3Extent = normalize(float3(1.0f, 1.0f, 1.0f));

	pf3Positions[0] = position + float3(-f2Size.x, 0.0f, -f2Size.y);
	pf3Positions[1] = position + float3(-f2Size.x, 0.0f, +f2Size.y);
	pf3Positions[2] = position + float3(+f2Size.x, 0.0f, -f2Size.y);
	pf3Positions[3] = position + float3(+f2Size.x, 0.0f, +f2Size.y);
	pf3Positions[4] = position + float3(-f2Size.x, 0.0f, 0.0f);
	pf3Positions[5] = position + float3(+f2Size.x, 0.0f, 0.0f);
	pf3Positions[6] = position + float3(0.0f, 0.0f, +f2Size.y);
	pf3Positions[7] = position + float3(0.0f, 0.0f, -f2Size.y);
}

float4 RandomDirection(float fOffset)
{
	int u = uint(gfCurrentTime + fOffset + frac(gfCurrentTime) * 1000.0f) % 1024;
	return(normalize(gRandomBuffer.Load(u)));
}

float4 RandomDirectionOnSphere(float fOffset)
{
	int u = uint(gfCurrentTime + fOffset + frac(gfCurrentTime) * 1000.0f) % 256;
	return(normalize(gRandomSphereBuffer.Load(u)));
}

void OutputParticleToStream(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
	input.position -= input.velocity * gfElapsedTime;
	input.velocity += gf3Gravity * gfElapsedTime;
	input.lifetime -= gfElapsedTime;

	output.Append(input);
}

void EmmitParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
	float4 f4Random = RandomDirection(input.type);
	if (input.lifetime <= 0.0f)
	{
		VS_PARTICLE_INPUT particle = input;
		particle.type = PARTICLE_TYPE_SHELL;
		particle.position = input.position + (input.velocity * gfElapsedTime * f4Random.xyz);
		particle.velocity = input.velocity + (f4Random.xyz * 16.0f);
		particle.lifetime = SHELL_PARTICLE_LIFETIME + (f4Random.y * 0.5f);

		output.Append(particle);

		input.lifetime = gfSecondsPerFirework * 0.2f + (f4Random.x * 0.4f);
	}
	else
	{
		input.lifetime -= gfElapsedTime;
	}

	output.Append(input);
}

void ShellParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
	if (input.lifetime <= 0.0f)
	{
		VS_PARTICLE_INPUT particle = input;
		float4 f4Random = float4(0.0f, 0.0f, 0.0f, 0.0f);

		particle.type = PARTICLE_TYPE_FLARE02;
		particle.position.x = input.position.x + (input.velocity * gfElapsedTime * 2.0f);
		particle.position.y = input.position.y - (input.velocity * gfElapsedTime * 2.0f);
		particle.position.z = input.position.z + (input.velocity * gfElapsedTime * 2.0f);
		particle.lifetime = FLARE02_PARTICLE_LIFETIME;

		for (int i = 0; i < gnFlareParticlesToEmit; i++)
		{
			f4Random = RandomDirection(input.type + i);
			f4Random.y = 0;
			particle.velocity = input.velocity + (f4Random.xyz * 18.0f);

			output.Append(particle);
		}

		particle.type = PARTICLE_TYPE_FLARE02;
		particle.position.x = input.position.x + (input.velocity * gfElapsedTime * 2.0f);
		particle.position.y = input.position.y;
		particle.position.z = input.position.z + (input.velocity * gfElapsedTime * 2.0f);
		for (int j = 0; j < abs(f4Random.x) * gnMaxFlareType2Particles; j++)
		{
			f4Random = RandomDirection(input.type + j);
			f4Random.y = 0;
			particle.velocity = input.velocity + (f4Random.xyz * 10.0f);
			particle.lifetime = FLARE02_PARTICLE_LIFETIME + (f4Random.x * 0.4f);

			output.Append(particle);
		}
	}
	else
	{
		OutputParticleToStream(input, output);
	}
}

void OutputEmberParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
	if (input.lifetime > 0.0f)
	{
		OutputParticleToStream(input, output);
	}
}

void GenerateEmberParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
	float4 f4Random = RandomDirection(input.type);
	if (input.lifetime <= 0.0f)
	{
		VS_PARTICLE_INPUT particle = input;

		particle.type = PARTICLE_TYPE_FLARE03;
		particle.position = input.position - (input.velocity * gfElapsedTime);
		particle.lifetime = FLARE03_PARTICLE_LIFETIME;
		for (int i = 0; i < 16; i++)
		{
			float4 f4Random = RandomDirectionOnSphere(input.type + i);
			particle.velocity = input.velocity + (f4Random.xyz);

			output.Append(particle);
		}
	}
	else
	{
		OutputParticleToStream(input, output);
	}
}

[maxvertexcount(128)]
void GSParticleStreamOutput(point VS_PARTICLE_INPUT input[1], inout PointStream<VS_PARTICLE_INPUT> output)
{
	VS_PARTICLE_INPUT particle = input[0];

	if (particle.type == PARTICLE_TYPE_EMITTER) 
		EmmitParticles(particle, output);
	else if (particle.type == PARTICLE_TYPE_SHELL) 
		ShellParticles(particle, output);
	else if (particle.type == PARTICLE_TYPE_FLARE02)
		GenerateEmberParticles(particle, output);
	else if  (particle.type == PARTICLE_TYPE_FLARE03)
		OutputEmberParticles(particle, output);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_PARTICLE_DRAW_OUTPUT
{
	float3 position : POSITION;
	float4 color : COLOR;
	float size : SCALE;
	uint type : PARTICLETYPE;
};

struct GS_PARTICLE_DRAW_OUTPUT
{
	float4 position : SV_Position;
	float4 color : COLOR;
	float2 uv : TEXTURE;
	uint type : PARTICLETYPE;
};

VS_PARTICLE_DRAW_OUTPUT VSParticleDraw(VS_PARTICLE_INPUT input)
{
	VS_PARTICLE_DRAW_OUTPUT output = (VS_PARTICLE_DRAW_OUTPUT)0;

	output.position = input.position;
	output.size = 2.5f;
	output.type = input.type;

	if (input.type == PARTICLE_TYPE_EMITTER) 
	{ 
		output.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
		output.size = 3.0f; 
	}
	else if (input.type == PARTICLE_TYPE_SHELL) 
	{ 
		output.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
		output.size = 3.0f; 
	}
	//else if (input.type == PARTICLE_TYPE_FLARE01) 
	//{ 
	//	output.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
	//	//output.color *= (input.lifetime / FLARE01_PARTICLE_LIFETIME); 
	//}
	else if (input.type == PARTICLE_TYPE_FLARE02)
	{
		output.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
		output.color *= (input.lifetime / FLARE02_PARTICLE_LIFETIME);
	}
	else if (input.type == PARTICLE_TYPE_FLARE03) 
	{ 
		output.color = float4(1.0f, 1.0f, 1.0f, 1.0f);
		output.color *= (input.lifetime / FLARE03_PARTICLE_LIFETIME); 
	}

	return(output);
}

static float3 gf3Positions[4] = { float3(-1.0f, +1.0f, 0.5f), float3(+1.0f, +1.0f, 0.5f), float3(-1.0f, -1.0f, 0.5f), float3(+1.0f, -1.0f, 0.5f) };
static float2 gf2QuadUVs[4] = { float2(0.0f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 1.0f), float2(1.0f, 1.0f) };

[maxvertexcount(4)]
void GSParticleDraw(point VS_PARTICLE_DRAW_OUTPUT input[1], inout TriangleStream<GS_PARTICLE_DRAW_OUTPUT> outputStream)
{
	GS_PARTICLE_DRAW_OUTPUT output = (GS_PARTICLE_DRAW_OUTPUT)0;

	output.type = input[0].type;
	output.color = input[0].color;
	for (int i = 0; i < 4; i++)
	{
		float3 positionW = mul(gf3Positions[i] * input[0].size, (float3x3)gmtxInverseView) + input[0].position;
		output.position = mul(mul(float4(positionW, 1.0f), gmtxView), gmtxProjection);
		output.uv = gf2QuadUVs[i];

		outputStream.Append(output);
	}
	outputStream.RestartStrip();
}

float4 PSParticleDraw(GS_PARTICLE_DRAW_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtParticleTexture.Sample(gssWrap, input.uv);
	cColor *= input.color;

	return(cColor);
}
