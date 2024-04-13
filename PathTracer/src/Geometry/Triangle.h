#pragma once
#include "Utils/cuda_math.h"
#include "Material.h"

struct Triangle
{
	float3 pos0;
	float3 pos1;
	float3 pos2;

	float3 normal0;
	float3 normal1;
	float3 normal2;

	float3 texCoord0;
	float3 texCoord1;
	float3 texCoord2;

	__host__ __device__ Triangle() = default;

	__host__ __device__ Triangle(float3 p0, float3 p1, float3 p2)
		:pos0(p0), pos1(p1), pos2(p2), normal0(make_float3(0.0f)), normal1(make_float3(0.0f)),
		normal2(make_float3(0.0f)), texCoord0(make_float3(0.0f)), texCoord1(make_float3(0.0f)), texCoord2(make_float3(0.0f)) { }

	__host__ __device__ Triangle(float3 p0, float3 p1, float3 p2, float3 n0, float3 n1, float3 n2)
		:pos0(p0), pos1(p1), pos2(p2), normal0(n0), normal1(n1),
		normal2(n2), texCoord0(make_float3(0.0f)), texCoord1(make_float3(0.0f)), texCoord2(make_float3(0.0f)) { }

	__host__ __device__ Triangle(float3 p0, float3 p1, float3 p2, float3 n0, float3 n1, float3 n2, float3 t0, float3 t1, float3 t2)
		:pos0(p0), pos1(p1), pos2(p2), normal0(n0), normal1(n1),
		normal2(n2), texCoord0(t0), texCoord1(t1), texCoord2(t2) { }


	// M�ller-Trumbore intersection algorithm. See https://en.wikipedia.org/wiki/M%C3%B6ller%E2%80%93Trumbore_intersection_algorithm

	inline __host__ __device__ bool Hit(const Ray& r, float& t)
	{
		float3 edge0 = pos1 - pos0;
		float3 edge1 = pos2 - pos0;

		float3 rayCrossEdge1 = cross(r.direction, edge1);
		float det = dot(edge0, rayCrossEdge1);

		if (det < 1.0e-6 && det > -1.0e-6)
			return false;

		float invDet = 1.0f / det;

		float3 s = r.origin - pos0;
		
		float u = invDet * dot(s, rayCrossEdge1);

		if (u < 0.0f || u > 1.0f)
			return false;

		float3 sCrossEdge0 = cross(s, edge0);
		float v = invDet * dot(r.direction, sCrossEdge0);

		if (v < 0.0f || u + v > 1.0f)
			return false;

		t = invDet * dot(edge1, sCrossEdge0);

		if (t > 0.0f)
			return true;

		return false;
	}

	inline __host__ __device__ float3 Normal()
	{
		float3 edge0 = pos1 - pos0;
		float3 edge1 = pos2 - pos0;

		return normalize(cross(edge0, edge1));
	}
};