gggggTexture2D txDiffuse : register(t0);
SamplerState samLinear : register(s0);

#define NUM_VERTS 4

//--------------------------------------------------------------------------------------
// Constant Buffer
//--------------------------------------------------------------------------------------
cbuffer ConstantBuffer : register(b0)
{
	matrix World;
	matrix View;
	matrix Projection;

	float3 CameraPosition;
	float FogEnabled;

	float2 Size;
	float FogStart;
	float FogRange;

	float4 FogColour;
}

//--------------------------------------------------------------------------------------
// Structs
//--------------------------------------------------------------------------------------
struct GS_OUTPUT
{
	float4 PosH : SV_POSITION;
	float2 Tex : TEXCOORD0;
	uint PrimID : SV_PrimitiveID;
	float3 PosW : POSITION;
};

struct GS_INPUT
{
	float4 PosW : POSITION;
};

//--------------------------------------------------------------------------------------
// Functions
//--------------------------------------------------------------------------------------

float4 CalculateFog(float4 currentColour, float distanceToEye)
{
	float4 resultColour = currentColour;

	if (FogEnabled == true)
	{
		float fogFactor = saturate((distanceToEye - FogStart) / FogRange);

		resultColour = lerp(resultColour, FogColour, fogFactor);
	}

	return resultColour;
}

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

GS_INPUT VS(float3 PosL : POSITION)
{
	GS_INPUT output = (GS_INPUT)0;
 
	output.PosW = mul(float4(PosL, 1.0f), World);

	return output;
}

//--------------------------------------------------------------------------------------
// Geometry Shader
//--------------------------------------------------------------------------------------
[maxvertexcount(NUM_VERTS)]
void GS(point GS_INPUT input[1], uint primID : SV_PrimitiveID, inout TriangleStream<GS_OUTPUT> OutputStream)
{
	float halfWidth = Size[0] / 2.0f;
	float halfHeight = Size[1] / 2.0f;

	float3 normal = CameraPosition - input[0].PosW.xyz;
	normal.y = 0.0f;

	normal = normalize(normal);

	float3 upVector = float3(0.0f, 1.0f, 0.0f);

	float3 rightVector = normalize(cross(normal, upVector)) * halfWidth;
	upVector *= halfHeight;

	//Creating billboard
	float3 vertices[NUM_VERTS];

	vertices[0] = input[0].PosW.xyz + rightVector - upVector; //bottom right
	vertices[1] = input[0].PosW.xyz + rightVector + upVector; //top right
	vertices[2] = input[0].PosW.xyz - rightVector - upVector; //bottom left
	vertices[3] = input[0].PosW.xyz - rightVector + upVector; //top left

	//Creating texCoords
	float2 texCoords[4];

	texCoords[0] = float2(0.0f, 1.0f);
	texCoords[1] = float2(0.0f, 0.0f);
	texCoords[2] = float2(1.0f, 1.0f);
	texCoords[3] = float2(1.0f, 0.0f);

	GS_OUTPUT output = (GS_OUTPUT)0;

	[unroll]
	for (int i = 0; i < NUM_VERTS; i++)
	{
		output.PosW = vertices[i];
		output.PosH = mul(float4(vertices[i], 1.0f), View);
		output.PosH = mul(output.PosH, Projection);
		output.Tex = texCoords[i];
		output.PrimID = primID;

		OutputStream.Append(output);
	}
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS(GS_OUTPUT input) : SV_Target
{
	float4 textureColour = { 1, 1, 1, 1 };
	textureColour = txDiffuse.Sample(samLinear, input.Tex);

	float4 finalColour;

	float distanceToEye = length(CameraPosition - input.PosW);

	finalColour.rgb = CalculateFog(textureColour, distanceToEye).xyz;
	finalColour.a = textureColour.a;

	clip(finalColour.a - 0.05f);

	return finalColour;

	//finalColour.rgb = textureColour.xyz;
}