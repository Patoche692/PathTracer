#pragma once
#include "../../Utils/cuda_math.h"
#include "../Ray.h"


struct Material {
	enum struct Type : char {
		LIGHT,
		DIFFUSE,
		PLASTIC,
		DIELECTRIC,
		CONDUCTOR
	};
	union {
		struct {
			float3 albedo;
		} diffuse;
		struct {
			float3 albedo;
			float roughness;
		} plastic;
	};
	Type materialType;
};
