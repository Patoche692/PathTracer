#pragma once

#include <cuda_runtime_api.h>
#include "Geometry/Material.h"
#include "Geometry/Mesh.h"
#include "Geometry/BVH/BVH.h"
#include "Geometry/BVH/BVHInstance.h"
#include "Geometry/BVH/TLAS.h"

void newDeviceMesh(Mesh& mesh, uint32_t size);
void newDeviceMaterial(Material& m, uint32_t size);
void freeDeviceMeshes(int meshesCount);
void freeDeviceMaterials();
void changeDeviceMaterial(Material& m, uint32_t id);
void CopyTLASData(TLAS& tl);
void freeDeviceTLAS();
Material** getMaterialSymbolAddress();
Mesh** getMeshSymbolAddress();
