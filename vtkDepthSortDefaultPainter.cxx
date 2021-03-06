/*=========================================================================

  Program:   Visualization Toolkit
  Module:    vtkDepthSortDefaultPainter.cxx

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notice for more information.

=========================================================================*/

// .NAME vtkDepthSortDefaultPainter
// .SECTION Thanks
// <verbatim>
//
//  This file is part of the DepthSorts plugin developed and contributed by
//
//  Copyright (c) CSCS - Swiss National Supercomputing Centre
//                EDF - Electricite de France
//
//  John Biddiscombe, Ugo Varetto (CSCS)
//  Stephane Ploix (EDF)
//
// </verbatim>

#include "vtkDepthSortDefaultPainter.h"

#include "vtkObjectFactory.h"
#include "vtkGarbageCollector.h"
#include "vtkMapper.h"
#include "vtkChooserPainter.h"
#include "vtkClipPlanesPainter.h"
#include "vtkPointsPainter.h"
#include "vtkStandardPolyDataPainter.h"
#include "vtkDepthSortPainter.h"
#include "vtkScalarsToColorsPainter.h"
#include "vtkTwoScalarsToColorsPainter.h"
#include "vtkDepthSortPolygonsPainter.h"
#ifdef PV_CUDA_PISTON_USE_PISTON
 #include "vtkPistonPolygonsPainter.h"
#endif
//----------------------------------------------------------------------------
vtkStandardNewMacro(vtkDepthSortDefaultPainter)
//----------------------------------------------------------------------------
vtkCxxSetObjectMacro(vtkDepthSortDefaultPainter, DepthSortPainter,          vtkDepthSortPainter)
vtkCxxSetObjectMacro(vtkDepthSortDefaultPainter, TwoScalarsToColorsPainter, vtkTwoScalarsToColorsPainter)
vtkCxxSetObjectMacro(vtkDepthSortDefaultPainter, DepthSortPolygonsPainter,  vtkDepthSortPolygonsPainter)
#ifdef PV_CUDA_PISTON_USE_PISTON
 #include "vtkPistonPolygonsPainter.h"
 vtkCxxSetObjectMacro(vtkDepthSortDefaultPainter, PistonPolygonsPainter,     vtkPistonPolygonsPainter)
#endif
//----------------------------------------------------------------------------
vtkDepthSortDefaultPainter::vtkDepthSortDefaultPainter()
{
  this->DepthSortPainter          = vtkDepthSortPainter::New();
  this->TwoScalarsToColorsPainter = vtkTwoScalarsToColorsPainter::New();
  this->DepthSortPolygonsPainter  = vtkDepthSortPolygonsPainter::New();
#ifdef PV_CUDA_PISTON_USE_PISTON
  this->PistonPolygonsPainter     = vtkPistonPolygonsPainter::New();
  this->EnablePiston = false;
#endif
  this->SetDisplayListPainter(NULL);
}
//----------------------------------------------------------------------------
vtkDepthSortDefaultPainter::~vtkDepthSortDefaultPainter()
{
  this->SetDepthSortPainter(NULL);
  this->SetTwoScalarsToColorsPainter(NULL);
  this->SetDepthSortPolygonsPainter(NULL);
#ifdef PV_CUDA_PISTON_USE_PISTON
  this->SetPistonPolygonsPainter(NULL);
#endif
}
//----------------------------------------------------------------------------
void vtkDepthSortDefaultPainter::ReportReferences(vtkGarbageCollector *collector)
{
  this->Superclass::ReportReferences(collector);
}
//----------------------------------------------------------------------------
void vtkDepthSortDefaultPainter::BuildPainterChain()
{
  // make sure the scalars to colour is using our painter
  this->SetScalarsToColorsPainter(this->TwoScalarsToColorsPainter);
  
  // build the superclass painter chain
  this->Superclass::BuildPainterChain();

#ifdef PV_CUDA_PISTON_USE_PISTON
  if (this->EnablePiston ) {
    vtkChooserPainter *chooserPainter = vtkChooserPainter::SafeDownCast(this->GetDelegatePainter());
    if (chooserPainter) {
      chooserPainter->SetPolyPainter(this->PistonPolygonsPainter);
    }
  }
  else {
#endif
    // insert our depth sort painter into the current painter chain :
    // ... -> ScalarsToColorsPainter -> DepthSortPainter -> ...
    this->DepthSortPainter->SetDelegatePainter(this->ScalarsToColorsPainter->GetDelegatePainter());
    this->ScalarsToColorsPainter->SetDelegatePainter(this->DepthSortPainter);
    vtkChooserPainter *chooserPainter = vtkChooserPainter::SafeDownCast(this->GetDelegatePainter());
    if (chooserPainter) {
      chooserPainter->SetPolyPainter(this->DepthSortPolygonsPainter);
    }
#ifdef PV_CUDA_PISTON_USE_PISTON
  }
#endif
}
//----------------------------------------------------------------------------
void vtkDepthSortDefaultPainter::PrintSelf(ostream& os, vtkIndent indent)
{
  this->Superclass::PrintSelf(os, indent);
  os << indent << "DepthSortPainter: "
      << this->DepthSortPainter << endl;
}
//----------------------------------------------------------------------------
