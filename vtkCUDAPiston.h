/*=========================================================================

  Program:   Visualization Toolkit
  Module:    vtkPistonPolygonsPainter.h

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notice for more information.

=========================================================================*/
// .NAME vtkPistonPolygonsPainter - this painter paints polygons.
// .SECTION Description
// This painter renders Polys in vtkPolyData. It can render the polys
// in any representation (VTK_POINTS, VTK_WIREFRAME, VTK_SURFACE).

#ifndef __vtkCUDAPiston_h
#define __vtkCUDAPiston_h

#include "pv_cuda_piston_configure.h" // For export macro
#include "vtkPistonDataObject.h"
#include "vtkgl.h"

class  vtkImageData;
class  vtkPolyData;
class  vtkRenderWindow;
struct cudaGraphicsResource; 

namespace vtkpiston {
  // Forward declarations of methods defined in the cuda implementation
  int  pv_cuda_piston_EXPORT GetCudaDeviceCount();
  void pv_cuda_piston_EXPORT CudaGLInit(int device);
  int  pv_cuda_piston_EXPORT QueryNumVerts(vtkPistonDataObject *id);
  int  pv_cuda_piston_EXPORT QueryVertsPer(vtkPistonDataObject *id);
  int  pv_cuda_piston_EXPORT QueryNumCells(vtkPistonDataObject *id);
  void pv_cuda_piston_EXPORT CudaRegisterBuffer(struct cudaGraphicsResource **vboResource, GLuint vboBuffer);
  void pv_cuda_piston_EXPORT CudaTransferToGL(vtkPistonDataObject *id, unsigned long dataObjectMTimeCache,
       struct cudaGraphicsResource **vboResources, 
       unsigned char *colorptr, double scalarrange[2], 
       double alpha, bool &hasNormals, bool &hasColors, bool &useindexbuffers);

  void pv_cuda_piston_EXPORT CopyToGPU(vtkImageData *id, vtkPistonDataObject *od);
  void pv_cuda_piston_EXPORT CopyToGPU(vtkPolyData *id, vtkPistonDataObject *od, bool useindexbuffer, char *scalarname, char *opacityname);
  void pv_cuda_piston_EXPORT DeleteData(vtkPistonReference *tr);
  void pv_cuda_piston_EXPORT DeepCopy(vtkPistonReference *tr, vtkPistonReference *other);
  void pv_cuda_piston_EXPORT CopyFromGPU(vtkPistonDataObject *id, vtkImageData *od);
  void pv_cuda_piston_EXPORT CopyFromGPU(vtkPistonDataObject *id, vtkPolyData *od);
};
namespace vtkpiston {
  void DepthSortPolygons(vtkPistonDataObject *id, double *cameravec, int direction);
};

namespace vtkpiston {
  extern bool pv_cuda_piston_EXPORT CudaGLInitted;
  // Description:
  // Manually call this before any cuda filters are created
  // to use direct GPU rendering.
  int pv_cuda_piston_EXPORT InitCudaGL(vtkRenderWindow *rw, int rank, int &displayId);

  // Description:
  // Return true if using cuda interop feature otherwise false.
  inline bool pv_cuda_piston_EXPORT IsEnabledCudaGL()
    {
    return vtkpiston::CudaGLInitted;
    }
};

#endif

