/*=========================================================================

  Program:   Visualization Toolkit
  Module:    vtkPistonDataWrangling.h

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notice for more information.

=========================================================================*/
// .NAME vtkPistonDataWrangling - Miscellaneous conversion code.
// .SECTION Description
// Miscellaneous code that is used in conversion between vtk and piston.
// The vtk_polydata struct is important as that is how piston's polygonal
// results get brought back to the CPU.

#ifndef __vtkPistonDataWrangling_h
#define __vtkPistonDataWrangling_h

#include <thrust/version.h>

#if (THRUST_MAJOR_VERSION>=1) && (THRUST_MINOR_VERSION>=7)
 #define SPACE thrust::device_system_tag
#elif (THRUST_MAJOR_VERSION>=1) && (THRUST_MINOR_VERSION>=6)
 #define SPACE thrust::device_space_tag
#else
 #define SPACE thrust::detail::default_device_space_tag
#endif

// typedef thrust::tuple<unsigned char, unsigned char, unsigned char, unsigned char> uchar4;

namespace vtkpiston {

typedef struct
{
  //GPU side representation of a vtkPolyData
  //this is the sibling of vtk_image3D in piston
  int nPoints;
  int vertsPer;
  int nCells;
  thrust::device_vector<float3>        *points;
  thrust::device_vector<uint3>         *cells;
  thrust::device_vector<uint3>         *originalcells;
  thrust::device_vector<float>          distances;
  thrust::device_vector<float>         *scalars;
  thrust::device_vector<float>         *opacities;
  thrust::device_vector<float>         *normals;
  thrust::device_vector<uchar4>        *colors;
  thrust::device_vector<uchar4>         lutRGBA;
  void *                                userPointer;
} vtk_polydata;

#ifdef __CUDACC__

struct tuple2float3 :
  thrust::unary_function<thrust::tuple<float, float, float>, float3>
{
    __host__ __device__
      float3 operator()(thrust::tuple<float, float, float> xyz) {
        return make_float3((float) thrust::get<0>(xyz),
                           (float) thrust::get<1>(xyz),
                           (float) thrust::get<2>(xyz));
    }
};

struct float4tofloat3 : thrust::unary_function<float4, float3>
{
  __host__ __device__
  float3 operator()(float4 xyzw) {
    return make_float3
          ((float) xyzw.x,
           (float) xyzw.y,
           (float) xyzw.z);
  }

};

#endif

} //namespace

#endif //__vtkPistonDataWrangling_h
// VTK-HeaderTest-Exclude: vtkPistonDataWrangling.h
