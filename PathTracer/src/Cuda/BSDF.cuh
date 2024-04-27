#pragma once
#include <cuda_runtime_api.h>
#include "Utils/cuda_math.h"
#include "Geometry/Material.h"
#include "Random.cuh"

#define ONE_DIV_PI (0.31830988618f)
#define TWO_TIMES_PI 6.28318530718f

struct BSDF {

	// for 
	// lambertianeval => for diffuesd FUNCTION
	// lambertianPDF FUNCTION

	float3 specularF0;
	float3 diffuseReflectance;

	float roughness;
	float alpha;
	float alphaSquared;

	float3 F;

	float3 V;	// Opposite incoming direction
	float3 N;	// Normal
	float3 H;	// Half vector
	float3 L;	// Outgoing direction

	float NdotL;
	float NdotV;

	float LdotH;
	float NdotH;
	float VdotH;

	bool VbackFacing;
	bool LbachFacing;

	inline __device__ float4 GetRotationToZAxis(float3 direction)
	{
		if (direction.z < -0.99999f) return make_float4(1.0f, 0.0f, 0.0f, 0.0f);
		return normalize(make_float4(direction.y, -direction.x, 0.0f, 1.0f + direction.z));
	}

	inline __device__ float4 GetRotationFromZAxis(float3 direction)
	{
		if (direction.z < -0.99999f) return make_float4(1.0f, 0.0f, 0.0f, 0.0f);
		return normalize(make_float4(-direction.y, direction.x, 0.0f, 1.0f + direction.z));
	}

	inline __device__ float4 InvertRotation(float4 q)
	{
		return make_float4(-q.x, -q.y, -q.z, q.w);
	}

	inline __device__ float3 RotatePoint(float4 q, float3 v)
	{
		const float3 qAxis = make_float3(q.x, q.y, q.z);
		return 2.0f * dot(qAxis, v) * qAxis + (q.w * q.w - dot(qAxis, qAxis)) * v + 2.0f * q.w * cross(qAxis, v);
	}

	inline __device__ void PrepareBSDFData(float3& scatteredLocal, float3& Vlocal,  Material& material)
	{
		V = Vlocal;
		L = scatteredLocal;
		H = normalize(V + L);
		float3 N = make_float3(0.0f, 0.0f, 1.0f);

		NdotL = dot(N, L);
		NdotV = dot(N, V);

		NdotL = fmin(fmax(0.00001f, NdotL), 1.0f);
		NdotV = fmin(fmax(0.00001f, NdotV), 1.0f);

		LdotH = clamp(dot(L, H), 0.0f, 1.0f);
		NdotH = clamp(dot(N, H), 0.0f, 1.0f);
		VdotH = clamp(dot(V, H), 0.0f, 1.0f);

		diffuseReflectance = BaseColorToDiffuseReflectance(material.diffuse, material.metalness);
		specularF0 = material.specular; //BaseColorToSpecular(material.diffuse, material.metalness);
		roughness = material.roughness;
		alpha = material.roughness * material.roughness;
		alphaSquared = alpha * alpha;

		//F = EvalFresnel(specularF0, shadowedF90(specularF0), LdotH);
		F = EvalFresnel(specularF0, 1, LdotH);

	}

	inline __device__ float3 EvalFresnelSchlick(float3 f0, float f90, float NdotS)
	{
		return f0 + (f90 - f0) * pow(1.0f - NdotS, 5.0f);
	}

	inline __device__ float3 EvalFresnel(float3 f0, float f90, float NdotS)
	{
		return EvalFresnelSchlick(f0, f90, NdotS);
	}

	inline __device__ float shadowedF90(float3 F0) {
		//const float t = 60.0f;
		const float t = (1.0f / 0.04);
		return min(1.0f, t * Luminance(F0));
	}

	inline __device__ float Luminance(float3 rgb)
	{
		return dot(rgb, make_float3(0.2126f, 0.7152f, 0.0722f));
	}

	inline __device__ float3 BaseColorToSpecular(const float3 baseColor, const float metalness, const float reflectance = 0.5f) {

		const float minDielectricsF0 = 0.16f * reflectance * reflectance;

		return lerp(make_float3(minDielectricsF0), baseColor, metalness);
	}

	inline __device__ float3 BaseColorToDiffuseReflectance(float3 baseColor, float metalness)
	{
		return baseColor * (1.0f - metalness);
	}

	inline __device__ float Lambertian()
	{
		return 1.0f;
	}

	inline __device__ float3 LambertianEval() {
		return diffuseReflectance * ONE_DIV_PI * NdotL;
	}

	inline __device__ float3 SampleSpecularHalfBeckWalt(float3 Vlocal, float2 alpha2D, unsigned int& rngState) {
		float alpha = dot(alpha2D, make_float2(0.5f, 0.5f));

		float2 u = make_float2(Random::Rand(rngState), Random::Rand(rngState));
		float tanThetaSquared = -(alpha * alpha) * log(1.0f - u.x);
		float phi = TWO_TIMES_PI * u.y;

		// Calculate cosTheta and sinTheta needed for conversion to H vector
		float cosTheta = 1.0 / sqrt(1.0f + tanThetaSquared);
		float sinTheta = sqrt(1.0f - cosTheta * cosTheta);

		// Convert sampled spherical coordinates to H vector
		return normalize(make_float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta));
	}

	inline __device__ float Beckmann_D(float alphaSquared, float NdotH)
	{
		float cos2Theta = NdotH * NdotH;
		float numerator = exp((cos2Theta - 1.0f) / (alphaSquared * cos2Theta));
		float denominator = M_PI * alphaSquared * cos2Theta * cos2Theta;
		return numerator / denominator;
	}

	inline __device__ float Smith_G_a(float alpha, float NdotS) {
		return NdotS / (max(0.00001f, alpha) * sqrt(1.0f - min(0.99999f, NdotS * NdotS)));
	}

	inline __device__ float Smith_G1_Beckmann_Walter(float a) {
		if (a < 1.6f) {
			return ((3.535f + 2.181f * a) * a) / (1.0f + (2.276f + 2.577f * a) * a);
		}
		else {
			return 1.0f;
		}
	}

	inline __device__ float Smith_G1_Beckmann_Walter(float alpha, float NdotS, float alphaSquared, float NdotSSquared) {
		return Smith_G1_Beckmann_Walter(Smith_G_a(alpha, NdotS));
	}

	inline __device__ float Smith_G2_Separable(float alpha, float NdotL, float NdotV) {
		float aL = Smith_G_a(alpha, NdotL);
		float aV = Smith_G_a(alpha, NdotV);
		return Smith_G1_Beckmann_Walter(aL) * Smith_G1_Beckmann_Walter(aV);
	}

	inline __device__ float Smith_G2(float alpha, float alphaSquared, float NdotL, float NdotV) {
		return Smith_G2_Separable(alpha, NdotL, NdotV);
	}

	inline __device__ bool Eval(HitResult& hitResult, float3& attenuation, float3& scattered, unsigned int& rngState)
	{
		float4 qRotationToZ = GetRotationToZAxis(hitResult.normal);
		float3 Vlocal = RotatePoint(qRotationToZ, -hitResult.rIn.direction);
		float3 Nlocal = make_float3(0.0f, 0.0f, 1.0f);

		float3 scatteredLocal = Random::RandomOnHemisphere(rngState, Nlocal);

		PrepareBSDFData(scatteredLocal, Vlocal, hitResult.material);

		//attenuation = diffuseReflectance * Lambertian();
		//float3 Hspecular = SampleSpecularHalfBeckWalt(Vlocal, make_float2(alpha), rngState);

		//float VdotH = max(0.00001f, min(1.0f, dot(Vlocal, Hspecular)));
		//attenuation *= (make_float3(1.0f, 1.0f, 1.0f) - EvalFresnel(specularF0, shadowedF90(specularF0), VdotH));

		//float D = Beckmann_D(max(0.00001f, alphaSquared), NdotH);
		//float G2 = Smith_G2(alpha, alphaSquared, NdotL, NdotV);

		float D = ((hitResult.material.shininess + 2) / (2.0 * M_PI)) * pow(NdotH, hitResult.material.shininess);
		float G = min(1.0, min(2.0 * NdotH * NdotV / VdotH, 2.0 * NdotH * NdotL / VdotH));
		float F = hitResult.material.specular.x + (1.0 - hitResult.material.specular.x) * pow(1.0 - VdotH, 5.0);

		attenuation = diffuseReflectance * Lambertian() * (1.0f - F) + make_float3(F * G * D / (4.0f * clamp(NdotL * NdotV, 0.00001f, 1.0f))) * NdotL;

		scattered = normalize(RotatePoint(InvertRotation(qRotationToZ), scatteredLocal));

		return true;
	}
};