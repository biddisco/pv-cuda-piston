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

#include "vtkCUDAPiston.h"
#include "vtkRenderWindow.h"
#include "vtkOpenGLExtensionManager.h"
//
#include <thrust/version.h>

//-----------------------------------------------------------------------------
bool vtkpiston::CudaGLInitted = 0;
//-----------------------------------------------------------------------------
int device_binding(int mpi_rank)
{
  int local_rank = mpi_rank;
  int dev_count, use_dev_count, my_dev_id;
  char *str;

  if ((str = getenv ("MV2_COMM_WORLD_LOCAL_RANK")) != NULL)
  {
    local_rank = atoi (str);
    printf ("MV2_COMM_WORLD_LOCAL_RANK %s\n", str);
  }

  if ((str = getenv ("MPISPAWN_LOCAL_NPROCS")) != NULL)
  {
    //num_local_procs = atoi (str);
    printf ("MPISPAWN_LOCAL_NPROCS %s\n", str);
  }

  dev_count = vtkpiston::GetCudaDeviceCount();
  if ((str = getenv ("NUM_GPU_DEVICES")) != NULL)
  {
    use_dev_count = atoi (str);
    printf ("NUM_GPU_DEVICES %s\n", str);
  }
  else
  {
    use_dev_count = dev_count;
  }

  my_dev_id = (use_dev_count>0) ? (local_rank % use_dev_count) : 0;
  printf ("local rank = %d dev id = %d\n", local_rank, my_dev_id);
  return my_dev_id;
}
//-----------------------------------------------------------------------------
int vtkpiston::InitCudaGL(vtkRenderWindow *rw, int rank, int &displayId)
{
  if (!vtkpiston::CudaGLInitted)
  {
    int major = THRUST_MAJOR_VERSION;
    int minor = THRUST_MINOR_VERSION;
    std::cout << "Thrust v" << major << "." << minor << std::endl;
    //
    vtkOpenGLExtensionManager *em = vtkOpenGLExtensionManager::New();
    em->SetRenderWindow(rw);
    em->Update();
    if (!em->LoadSupportedExtension("GL_VERSION_1_5"))
    {
      std::cout << "WARNING: GL_VERSION_1_5 unsupported Can not use direct piston rendering" << endl;
      std::cout << em->GetExtensionsString() << std::endl;
      em->FastDelete();
      return 0;
    }
    em->FastDelete();
    if (displayId<0 || displayId>=vtkpiston::GetCudaDeviceCount()) {
      // try another method to get the device ID
      displayId = device_binding(rank);
    }
    vtkpiston::CudaGLInitted = true;
    vtkpiston::CudaGLInit(displayId);
  }
  return 1;
}

