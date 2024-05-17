#include "BVHInstance.h"
#include "Utils/Utils.h"

void BVHInstance::SetTransform(Mat4& t)
{
	transform = t;
	invTransform = t.Inverted();
	float3 bMin = bvh->nodes[0].aabbMin;
	float3 bMax = bvh->nodes[0].aabbMax;
	bounds = AABB();
	for (int i = 0; i < 8; i++)
	{
		bounds.Grow(TransformPosition(make_float3(i & 1 ? bMax.x : bMin.x,
			i & 2 ? bMax.y : bMin.y, i & 4 ? bMax.z : bMin.z), t));
	}
}

void BVHInstance::SetTransform(float3 pos, float3 r, float3 s)
{
	Mat4 t = Mat4::Translate(pos) * Mat4::RotateX(Utils::ToRadians(r.x))
		* Mat4::RotateY(Utils::ToRadians(r.y)) * Mat4::RotateZ(Utils::ToRadians(r.z)) * Mat4::Scale(s);
	SetTransform(t);
}

void BVHInstance::AssignMaterial(int mId)
{
	materialId = mId;
}