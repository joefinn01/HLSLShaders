//--------------------------------------------------------------------------------------
// File: DX11 Framework.fx
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
#define MAX_LIGHTS 5

#define DIRECTIONAL_LIGHT 0
#define POINT_LIGHT 1
#define SPOT_LIGHT 2

struct Light
{
	float4 Position;
	float4 Direction;
	
	float4 Ambient;
	float4 Diffuse;
	float4 Specular;

	float3 Attenuation;
	float SpotLightAngle;

	int LightType;
	int Enabled;
	float Range;
};

struct LightingResult
{
	float4 Ambient;
	float4 Diffuse;
	float4 Specular;
};

cbuffer ConstantBuffer : register( b0 )
{
	matrix World;
	matrix WorldInverseTranspose;
	matrix View;
	matrix Projection;

	float4 AmbientMtrl;
	float4 DiffuseMtrl;
	float4 SpecularMtrl;

	Light Lights[MAX_LIGHTS];

	float3 EyePosW;
	float FogEnabled;

	float FogStart;
	float FogRange;

	float4 FogColour;
}

Texture2D txDiffuse : register(t0);
SamplerState samLinear : register(s0);

//--------------------------------------------------------------------------------------
struct VS_INPUT
{
	float3 Pos : POSITION;
	float3 NormalL : NORMAL;
	float2 Tex : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 Pos : SV_POSITION;
	float3 Norm : NORMAL;
	float3 PosW : POSITION;
	float2 Tex : TEXCOORD0;
};

//------------------------------------------------------------------------------------
// Vertex Shader - Implements Gouraud Shading using Diffuse lighting only
//------------------------------------------------------------------------------------

LightingResult InitLight()
{
	LightingResult result;

	result.Ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
	result.Diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
	result.Specular = float4(0.0f, 0.0f, 0.0f, 0.0f);

	return result;
}

LightingResult CalculatePointLight(Light light, float3 viewVector, float4 position, float3 normal)
{
	LightingResult result = InitLight();

	float3 lightVectorFromPoint = (light.Position - position).xyz;

	float distance = length(lightVectorFromPoint);

	if (distance > light.Range)
	{
		return result;
	}

	lightVectorFromPoint /= distance;

	result.Ambient = AmbientMtrl * light.Ambient;

	float diffuseIntensity = dot(lightVectorFromPoint, normal);

	if (diffuseIntensity > 0.0f)
	{
		float3 reflected = reflect(-lightVectorFromPoint, normal);
		float specularIntensity = pow(max(dot(reflected, viewVector), 0.0f), SpecularMtrl.w);

		result.Diffuse = diffuseIntensity * DiffuseMtrl * light.Diffuse;
		result.Specular = specularIntensity * SpecularMtrl * light.Specular;
	}

	float attenuation = 1.0f / dot(light.Attenuation[0], float3(1.0f, light.Attenuation[1] * distance, light.Attenuation[2] * distance * distance));

	result.Diffuse *= attenuation;
	result.Specular *= attenuation;

	return result;
}

LightingResult CalculateDirectionalLight(Light light, float3 viewVector, float3 normal)
{
	LightingResult result = InitLight();

	float3 lightVectorFromPoint = -light.Direction.xyz;

	result.Ambient = AmbientMtrl * light.Ambient;

	float diffuseIntensity = dot(lightVectorFromPoint, normal);

	if (diffuseIntensity > 0.0f)
	{
		float3 reflected = reflect(-lightVectorFromPoint, normal);
		float specularIntensity = pow(max(dot(reflected, viewVector), 0.0f), SpecularMtrl.w);

		result.Diffuse = diffuseIntensity * DiffuseMtrl * light.Diffuse;
		result.Specular = specularIntensity * SpecularMtrl * light.Specular;
	}

	return result;
}

LightingResult CalculateSpotLight(Light light, float3 viewVector, float4 position, float3 normal)
{
	LightingResult result = InitLight();

	float3 lightVectorFromPoint = (light.Position - position).xyz;

	float distance = length(lightVectorFromPoint);

	if (distance > light.Range)
		return result;

	lightVectorFromPoint /= distance;

	result.Ambient = AmbientMtrl * light.Ambient;

	float diffuseIntensity = dot(lightVectorFromPoint, normal);

	if (diffuseIntensity > 0.0f)
	{
		float3 reflected = reflect(-lightVectorFromPoint, normal);
		float specularIntensity = pow(max(dot(reflected, viewVector), 0.0f), SpecularMtrl.w);

		result.Diffuse = diffuseIntensity * DiffuseMtrl * light.Diffuse;
		result.Specular = specularIntensity * SpecularMtrl * light.Specular;
	}

	float spotLightIntensity = pow(max(dot(-lightVectorFromPoint, light.Direction.xyz), 0.0f), light.SpotLightAngle);

	float attenuation = 1.0f / dot(light.Attenuation[0], float3(1.0f, light.Attenuation[1] * distance, light.Attenuation[2] * distance * distance));

	result.Ambient *= spotLightIntensity;
	result.Diffuse *= attenuation * spotLightIntensity;
	result.Specular *= attenuation * spotLightIntensity;

	return result;
}

LightingResult CalculateLight(float3 position, float3 normal)
{
	float3 viewVector = normalize(EyePosW - position.xyz);

	LightingResult totalResult = InitLight();

	for (int i = 0; i < MAX_LIGHTS; i++)
	{
		LightingResult result = InitLight();

		if (Lights[i].Enabled == 1)
		{
			switch (Lights[i].LightType)
			{
			case DIRECTIONAL_LIGHT:
				result = CalculateDirectionalLight(Lights[i], viewVector, normal);
				break;

			case POINT_LIGHT:
				result = CalculatePointLight(Lights[i], viewVector, float4(position, 1.0f), normal);
				break;

			case SPOT_LIGHT:
				result = CalculateSpotLight(Lights[i], viewVector, float4(position, 1.0f), normal);
				break;
			}

			totalResult.Ambient += result.Ambient;
			totalResult.Diffuse += result.Diffuse;
			totalResult.Specular += result.Specular;
		}
	}

	totalResult.Ambient = saturate(totalResult.Ambient);
	totalResult.Diffuse = saturate(totalResult.Diffuse);	//Clamp value in range 0 and 1 with saturate
	totalResult.Specular = saturate(totalResult.Specular);

	return totalResult;
}

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

VS_OUTPUT VS(VS_INPUT input)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	output.Pos = mul(float4(input.Pos, 1.0f), World);

	//Setting vertex Pos in world Coords
	output.PosW = output.Pos.xyz;

	//Transform to projection view
	output.Pos = mul(output.Pos, View);
	output.Pos = mul(output.Pos, Projection);

	output.Norm = mul(float4(input.NormalL,1.0f), WorldInverseTranspose).xyz;

	output.Tex = input.Tex;

	return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS( VS_OUTPUT input ) : SV_Target
{
 //   return Colour;

	LightingResult result = CalculateLight(input.PosW, normalize(input.Norm));	//Normalize as interpolation can cause vector not to be normal

	float4 textureColour = { 1, 1, 1, 1 };

	textureColour = txDiffuse.Sample(samLinear, input.Tex);

	float4 litColour = textureColour * (result.Ambient + result.Diffuse) + result.Specular;

	float4 finalColour;

	float distanceToEye = length(input.PosW - EyePosW);

	finalColour.rgb = CalculateFog(litColour, distanceToEye).rgb;
	finalColour.a = DiffuseMtrl.a * textureColour.a;

	return finalColour;
}