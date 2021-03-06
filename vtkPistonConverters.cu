//
// cuda + thrust
//
#include <vector_types.h>
#include <thrust/copy.h>
#include <piston/choose_container.h>
#include <piston/image3d.h>
#include <piston/vtk_image3d.h>
//
// VTK
//
#include "vtkCellArray.h"
#include "vtkFloatArray.h"
#include "vtkDoubleArray.h"
#include "vtkIdTypeArray.h"
#include "vtkUnsignedCharArray.h"
#include "vtkImageData.h"
#include "vtkPointData.h"
#include "vtkPolyData.h"
#include "vtkPistonDataObject.h"
#include "vtkPistonDataWrangling.h"
#include "vtkPistonReference.h"
#include "vtkCUDAPiston.h"

#include "vtkgl.h"

#include <iostream>
#include <algorithm>

using namespace std;
using namespace piston;

  //-----------------------------------------------------------------------------
  void vtkpiston::DeleteData(vtkPistonReference *tr)
  {
    if (tr == NULL || tr->data == NULL)
    {
      return;
    }
    switch(tr->type)
    {
    case VTK_IMAGE_DATA:
      {
        vtk_image3d<SPACE>*oldD =
          (vtk_image3d<SPACE>*)tr->data;
        delete oldD;
      }
      break;
    case VTK_POLY_DATA:
      {
        vtkpiston::vtk_polydata *oldD = (vtkpiston::vtk_polydata *)tr->data;
        if (oldD->points)
        {
          oldD->points->clear();
        }
        delete oldD->points;
        if (oldD->cells)
        {
          oldD->cells->clear();
        }
        delete oldD->cells;
        if (oldD->originalcells)
        {
          oldD->originalcells->clear();
        }
        delete oldD->originalcells;
        if (oldD->scalars)
        {
          oldD->scalars->clear();
        }
        delete oldD->scalars;
        if (oldD->colors)
        {
          oldD->colors->clear();
        }
        delete oldD->colors;
        if (oldD->opacities)
        {
          oldD->opacities->clear();
        }
        delete oldD->opacities;
        if (oldD->normals)
        {
          oldD->normals->clear();
        }
        delete oldD->normals;
        if (oldD->userPointer) {
          cudaFree(oldD->userPointer);
        }
        delete oldD;
      }
      break;
    default:
      cerr << "I don't have a deallocator for " << tr->type << " yet." << endl;
    }
    tr->data = NULL;
    tr->type = -1;
  }

  //-----------------------------------------------------------------------------
  void vtkpiston::DeepCopy(vtkPistonReference *tr, vtkPistonReference *other)
  {
    if (tr == NULL)
    {
      return;
    }
    vtkpiston::DeleteData(tr);
    if (other == NULL)
    {
      return;
    }

    switch(other->type)
    {
    case VTK_IMAGE_DATA:
      {
        vtk_image3d<SPACE>*oldD =
          (vtk_image3d<SPACE>*)other->data;
        thrust::device_vector<float>*scalars = new thrust::device_vector<float>(oldD->NPoints);
        thrust::copy(oldD->point_data_begin(), oldD->point_data_end(), scalars->begin());
        int dims[3];
        dims[0] = oldD->dim0;
        dims[1] = oldD->dim1;
        dims[2] = oldD->dim2;
        vtk_image3d<SPACE> *newD = new vtk_image3d<SPACE>(
          dims, oldD->origin, oldD->spacing, oldD->extents, *scalars);
        tr->data = (void*)newD;
      }
      break;
    case VTK_POLY_DATA:
      {
        vtkpiston::vtk_polydata *oldD = (vtkpiston::vtk_polydata *)other->data;
        vtkpiston::vtk_polydata *newD = new vtkpiston::vtk_polydata;
        newD->nPoints = oldD->nPoints;
        newD->vertsPer = oldD->vertsPer;
        newD->points = new thrust::device_vector<float3>(oldD->points->size());
        thrust::copy(oldD->points->begin(), oldD->points->end(), newD->points->begin());

        if (oldD->cells) {
          newD->cells = new thrust::device_vector<uint3>(oldD->cells->size());
          thrust::copy(oldD->cells->begin(), oldD->cells->end(), newD->cells->begin());
          //
          newD->originalcells = new thrust::device_vector<uint3>(oldD->originalcells->size());
          thrust::copy(oldD->originalcells->begin(), oldD->originalcells->end(), newD->originalcells->begin());
        }
        else {
          newD->cells = NULL;
          newD->originalcells = NULL;
        }

        newD->scalars = new thrust::device_vector<float>(oldD->scalars->size());
        thrust::copy(oldD->scalars->begin(), oldD->scalars->end(), newD->scalars->begin());
        newD->colors = new thrust::device_vector<uchar4>(oldD->colors->size());
        thrust::copy(oldD->colors->begin(), oldD->colors->end(), newD->colors->begin());

        if (oldD->opacities) {
          newD->opacities = new thrust::device_vector<float>(oldD->opacities->size());
          thrust::copy(oldD->opacities->begin(), oldD->opacities->end(), newD->opacities->begin());
        }
        else {
          newD->opacities = NULL;
        }

        newD->normals = new thrust::device_vector<float>(oldD->normals->size());
        thrust::copy(oldD->normals->begin(), oldD->normals->end(), newD->normals->begin());
        tr->data = (void*)newD;
      }
      break;
    default:
      cerr << "I don't have a copy method for " << tr->type << " yet." << endl;
    }
    tr->type = other->type;
  }

  //-----------------------------------------------------------------------------
  bool CheckDirty(vtkDataSet *ds, vtkPistonReference *tr)
  {
    unsigned long int dstime = ds->GetMTime();
    if (dstime != tr->mtime)
    {
      tr->mtime = dstime;
      return true;
    }
    return false;
  }

  //-----------------------------------------------------------------------------
  vtkFloatArray *makeScalars(thrust::host_vector<float> *D)
  {
    //copy from thrust to C
    int nPoints = D->size();
    float *raw_ptr = thrust::raw_pointer_cast(&*(D->begin()));
    float *toArray = new float[nPoints];
    memcpy(toArray, raw_ptr, nPoints*sizeof(float));

    //wrap result in vtkArray container
    vtkFloatArray *outfloats = vtkFloatArray::New();
    outfloats->SetNumberOfComponents(1);
    outfloats->SetArray(toArray, nPoints, 0); //0 let vtkArray delete[] toArray
    return outfloats;
  }

  //-----------------------------------------------------------------------------
  vtkUnsignedCharArray *makeScalars(thrust::host_vector<unsigned char> *D)
  {
    //copy from thrust to C
    int nPoints = D->size();
    unsigned char *raw_ptr = thrust::raw_pointer_cast(&*(D->begin()));
    unsigned char *toArray = new unsigned char[nPoints];
    memcpy(toArray, raw_ptr, nPoints*sizeof(unsigned char));

    //wrap result in vtkArray container
    vtkUnsignedCharArray *outvals = vtkUnsignedCharArray::New();
    outvals->SetNumberOfComponents(1);
    outvals->SetArray(toArray, nPoints, 0); //0 let vtkArray delete[] toArray
    return outvals;
  }

  //-----------------------------------------------------------------------------
  vtkFloatArray *makeNormals(thrust::host_vector<float> *D)
  {
    //copy from thrust to C
    int nPoints = D->size()/3;
    float *raw_ptr = thrust::raw_pointer_cast(&*(D->begin()));
    float *toArray = new float[nPoints*3];
    memcpy(toArray, raw_ptr, 3*nPoints*sizeof(float));

    //wrap result in vtkArray container
    vtkFloatArray *outfloats = vtkFloatArray::New();
    outfloats->SetNumberOfComponents(3);
    outfloats->SetName("Normals");
    outfloats->SetArray(toArray, nPoints*3, 0);//0 lets vtkArray delete[] toArray
    return outfloats;
  }

  //-----------------------------------------------------------------------------
  // The dummy args are to allow the compiler to select the right specialization
  // from the vtk template macro
  template <typename vtkType, typename cudaType>
  void dataArrayToThrust(
    vtkDataArray *dataarray, thrust::device_vector<cudaType> *&result, vtkIdType maxN,
    vtkType *dummy, cudaType *dummy2)
  {
    vtkType *dataptr = static_cast<vtkType*>(dataarray->GetVoidPointer(0));
    vtkIdType Nt = dataarray->GetNumberOfTuples();
    vtkIdType Nc = dataarray->GetNumberOfComponents();
    // limit the size incase a vector array was passed instead of a scalar array
    vtkIdType N = std::min(maxN, Nc*Nt);
    // create a host array with vtkDataArray contents
    thrust::host_vector<cudaType> hA(N);
    for (vtkIdType i=0; i<N; i++) {
      hA[i] = static_cast<cudaType>(dataptr[i]);
    }
    // create a device arrray
    result = new thrust::device_vector<cudaType>(N);
    // copy host array into device array
    *result = hA;
  }

  //-----------------------------------------------------------------------------
  int vtkpiston::QueryNumVerts(vtkPistonDataObject *id)
  {
    vtkPistonReference *tr = id->GetReference();
    if (tr->type != VTK_POLY_DATA || tr->data == NULL)
    {
      //type mismatch, don't bother trying
      return 0;
    }
    vtk_polydata *pD = (vtk_polydata *)tr->data;
    return pD->nPoints;
  }

  //-----------------------------------------------------------------------------
  int vtkpiston::QueryNumCells(vtkPistonDataObject *id)
  {
    vtkPistonReference *tr = id->GetReference();
    if (tr->type != VTK_POLY_DATA || tr->data == NULL)
    {
      //type mismatch, don't bother trying
      return 0;
    }
    vtk_polydata *pD = (vtk_polydata *)tr->data;
    return pD->nCells;
  }

  //-----------------------------------------------------------------------------
  int vtkpiston::QueryVertsPer(vtkPistonDataObject *id)
  {
    vtkPistonReference *tr = id->GetReference();
    if (tr->type != VTK_POLY_DATA || tr->data == NULL)
    {
      //type mismatch, don't bother trying
      return 0;
    }
    vtk_polydata *pD = (vtk_polydata *)tr->data;
    return pD->vertsPer;
  }

  //-----------------------------------------------------------------------------
  void vtkpiston::CopyToGPU(vtkImageData *id, vtkPistonDataObject *od)
  {
    vtkPistonReference *tr = od->GetReference();
    if (CheckDirty(id, tr))
    {
      vtkpiston::DeleteData(tr);
      vtk_image3d<SPACE> *newD =
        new vtk_image3d<SPACE>(id);
      tr->data = (void*)newD;
      if(id->GetPointData() && id->GetPointData()->GetScalars())
      {
        od->SetScalarsArrayName(id->GetPointData()->GetScalars()->GetName());
      }
    }
    tr->type = VTK_IMAGE_DATA;
  }

  //-----------------------------------------------------------------------------
  void vtkpiston::AllocGPU(vtkPolyData *id, vtkPistonDataObject *od)
  {
    vtkPistonReference *tr = od->GetReference();
    tr->type = VTK_POLY_DATA;
    if (!CheckDirty(id, tr)) {
      return;
    }
    //
    // clean previous state
    //
    vtkpiston::DeleteData(tr);

    //
    // allocate a new polydata device object
    //
    vtkpiston::vtk_polydata *newD = new vtkpiston::vtk_polydata;
    tr->data = (void*)newD;
    //
    newD->points        = NULL;
    newD->cells         = NULL;
    newD->originalcells = NULL;
    newD->scalars       = NULL;
    newD->opacities     = NULL;
    newD->normals       = NULL;
    newD->colors        = NULL;
    newD->userPointer   = NULL;
    newD->vertsPer      = 0;
    newD->nCells        = 0;
    //
    int nPoints = id->GetNumberOfPoints();
    newD->nPoints = nPoints;  
  }

  //-----------------------------------------------------------------------------
  void vtkpiston::CopyToGPU(vtkPolyData *id, vtkPistonDataObject *od, bool useindexbuffer, char *scalarname, char *opacityname)
  {
    vtkPistonReference *tr = od->GetReference();
    tr->type = VTK_POLY_DATA;
    if (!CheckDirty(id, tr)) {
      return;
    }
    //
    // clean previous state
    //
    vtkpiston::DeleteData(tr);

    //
    // allocate a new polydata device object
    //
    vtkpiston::vtk_polydata *newD = new vtkpiston::vtk_polydata;
    tr->data = (void*)newD;

    //
    //
    //
    int nPoints = id->GetNumberOfPoints();
    newD->nPoints = nPoints;

    thrust::host_vector<float3> hG(nPoints);
    for (vtkIdType i = 0; i < nPoints; i++) {
      double *next = id->GetPoint(i);
      hG[i].x = (float)next[0];
      hG[i].y = (float)next[1];
      hG[i].z = (float)next[2];
    }
    thrust::device_vector<float3> *dG = new thrust::device_vector<float3>(nPoints);
    *dG = hG;
    newD->points = dG;
    //
    newD->vertsPer = 3;

    //
    // This routine assumes that only triangles exist in the polydata
    //
    vtkCellArray *cellarray = vtkCellArray::SafeDownCast(id->GetPolys());
    if (useindexbuffer && cellarray && cellarray->GetNumberOfCells()) {
      vtkIdType ncells = cellarray->GetNumberOfCells();
      newD->nCells = ncells;
      thrust::host_vector<uint3> hA(ncells);
      vtkIdType   npts = 0;
      vtkIdType *index = 0;
      int            i = 0;
      for (cellarray->InitTraversal(); cellarray->GetNextCell(npts, index); i++) {
        hA[i].x = index[0];
        hA[i].y = index[1];
        hA[i].z = index[2];
      }
      thrust::device_vector<uint3> *dA1 = new thrust::device_vector<uint3>(ncells);
      thrust::device_vector<uint3> *dA2 = new thrust::device_vector<uint3>(ncells);
      *dA1 = hA; // copy contents
      *dA2 = hA; // copy contents
      newD->cells         = dA1;
      newD->originalcells = dA2;
      //
    }
    else {
      newD->nCells = 0;
      newD->cells = NULL;
      newD->originalcells = NULL;
    }

    // Scalars
    // Templated copy from vtkDataArray<any> into cuda float array
    //
    vtkDataArray *inscalars = id->GetPointData()->GetArray(scalarname);
    if (inscalars) {
      switch(inscalars->GetDataType()) {
        vtkTemplateMacro(
          dataArrayToThrust(inscalars, newD->scalars, nPoints,
            static_cast<VTK_TT*>(0), static_cast<float *>(0)));
      }
      od->SetScalarsArrayName(inscalars->GetName());
    }
    else {
      newD->scalars = NULL;
    }

    // Opacity
    // Templated copy from vtkDataArray<any> into cuda float array
    //
    vtkDataArray *inopacities = id->GetPointData()->GetArray(opacityname);
    if (inopacities) {
      switch(inopacities->GetDataType()) {
        vtkTemplateMacro(
          dataArrayToThrust(inopacities, newD->opacities, nPoints,
            static_cast<VTK_TT*>(0), static_cast<float *>(0)));
      }
    }
    else {
      newD->opacities = NULL;
    }

    // Normals
    // Templated copy from vtkDataArray<any> into cuda float array
    //
    vtkDataArray *normals = id->GetPointData()->GetNormals();
    if (!normals) {
      normals = id->GetPointData()->GetArray("Normals");
    }
    if (normals) {
      switch(normals->GetDataType()) {
        vtkTemplateMacro(
          dataArrayToThrust(normals, newD->normals, nPoints*3,
            static_cast<VTK_TT*>(0), static_cast<float *>(0)));
      }
    }
    else {
      newD->normals = NULL;
    }

    vtkUnsignedCharArray *incolors = vtkUnsignedCharArray::SafeDownCast(
      id->GetPointData()->GetArray("Color"));
    if (incolors)
    {
      thrust::host_vector<uchar4> hA(nPoints);
      unsigned char *next = incolors->GetPointer(0);
      for (vtkIdType i=0; i<nPoints; i++) {
        hA[i] = make_uchar4(next[0], next[1], next[2], next[3]);;
        next+=4;
      }
      // copy from host vector to device vector
      newD->colors = new thrust::device_vector<uchar4>(nPoints);
      *(newD->colors) = hA;
    }
    else
    {
      newD->colors = NULL;
    }
  }

  //-----------------------------------------------------------------------------
  void vtkpiston::CopyFromGPU(vtkPistonDataObject *id, vtkImageData *od)
  {
    vtkPistonReference *tr = id->GetReference();
    if (tr->type != VTK_IMAGE_DATA || tr->data == NULL)
    {
      //type mismatch, don't bother trying
      return;
    }
    if (!CheckDirty(od, tr))
    {
      //it hasn't changed, don't recompute
      return;
    }
    vtk_image3d<SPACE>*oldD =
      (vtk_image3d<SPACE>*)tr->data;

    //geometry/topology
    od->SetExtent(0, oldD->dim0-1, 0, oldD->dim1-1, 0, oldD->dim2-1);
    od->SetOrigin(id->GetOrigin());
    od->SetSpacing(id->GetSpacing());

    //attributes
    int nPoints = oldD->NPoints;
    thrust::host_vector<float> D(nPoints);
    thrust::copy(oldD->point_data_begin(), oldD->point_data_end(), D.begin());
    //assign that to the output dataset
    vtkFloatArray *outFloats = makeScalars(&D);
    outFloats->SetName(id->GetScalarsArrayName());
    od->GetPointData()->SetScalars(outFloats);
    outFloats->Delete();
  }

  //-----------------------------------------------------------------------------
  void vtkpiston::CopyFromGPU(vtkPistonDataObject *id, vtkPolyData *od)
  {
    vtkPistonReference *tr = id->GetReference();
    if (tr->type != VTK_POLY_DATA || tr->data == NULL)
    {
      //type mismatch, don't bother trying
      return;
    }
    if (!CheckDirty(od,tr))
    {
      //it hasn't changed, don't recompute
      return;
    }

    vtkpiston::vtk_polydata *pD = (vtkpiston::vtk_polydata *)tr->data;
    int nPoints = pD->nPoints;

    //geometry
    vtkPoints *points = vtkPoints::New();
    od->SetPoints(points);
    points->Delete();
    points->SetDataTypeToFloat();
    points->SetNumberOfPoints(nPoints);
    thrust::host_vector<float3> G(nPoints);
    thrust::copy(pD->points->begin(), pD->points->end(), G.begin());
    float *raw_ptr = thrust::raw_pointer_cast(&G[0].x);
    float *toPoints = (float*)points->GetVoidPointer(0);
    memcpy(toPoints, raw_ptr, nPoints*3*sizeof(float));

    //topology
    int vertsPer = pD->vertsPer;
    int nCells = nPoints/vertsPer;
    od->Allocate(nCells);
    vtkCellArray *cells = od->GetPolys();
    vtkIdTypeArray *cl = vtkIdTypeArray::New();
    cells->SetCells(nCells, cl);
    cl->Delete();
    cl->SetNumberOfValues(nCells*(vertsPer+1));
    for (int i = 0; i < nCells; i++)
    {
      cl->SetValue(i*(vertsPer+1)+0,vertsPer);
      for (int j = 0; j < vertsPer; j++)
      {
        cl->SetValue(i*(vertsPer+1)+j+1,i*vertsPer+j);
      }
    }

    //attributes
    //scalars
    if (pD->scalars)
    {
      thrust::host_vector<float> V(nPoints);
      thrust::copy(pD->scalars->begin(), pD->scalars->end(), V.begin());
      //assign that to the output dataset
      vtkFloatArray *outScalars = makeScalars(&V);
      outScalars->SetName(id->GetScalarsArrayName());
      od->GetPointData()->SetScalars(outScalars);
      outScalars->Delete();
    }

    //attributes
    //colors
    if (pD->colors)
    {
      thrust::host_vector<uchar4> V(nPoints);
      thrust::copy(pD->colors->begin(), pD->colors->end(), V.begin());
      //assign that to the output dataset
//      vtkUnsignedCharArray *outColors = makeScalars(&V);
//      outColors->SetName(id->GetScalarsArrayName());
//      od->GetPointData()->AddArray(outColors);
//      outColors->Delete();
    }
    if (pD->opacities)
    {
      thrust::host_vector<float> V(nPoints);
      thrust::copy(pD->opacities->begin(), pD->opacities->end(), V.begin());
      //assign that to the output dataset
      vtkFloatArray *outOpacities = makeScalars(&V);
      outOpacities->SetName("Opacity");
      od->GetPointData()->AddArray(outOpacities);
      outOpacities->Delete();
    }
    //normals
    if (pD->normals)
    {
      thrust::host_vector<float> N(nPoints*3);
      thrust::copy(pD->normals->begin(), pD->normals->end(), N.begin());
      //assign that to the output dataset
      vtkFloatArray *outNormals = makeNormals(&N);
      od->GetPointData()->SetNormals(outNormals);
      outNormals->Delete();
    }
  }
