/*=========================================================================

  Program:   Visualization Toolkit
  Module:    vtkDataSetToPiston.h

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notice for more information.

=========================================================================*/
// .NAME vtkDataSetToPiston - converts a DataSet to a PistonDataObject
// .SECTION Description
// Converts vtkDataSets that reside on the CPU into piston data that
// resides on the GPU. Afterward vtkPistonAlgorithms will processed
// it there.
//
// .SECTION See Also
// vtkPistonToDataSet

#ifndef __vtkDataSetToPiston_h
#define __vtkDataSetToPiston_h

#include "vtkPistonAlgorithm.h"

class vtkDataSet;

class pv_cuda_piston_EXPORT vtkDataSetToPiston : public vtkPistonAlgorithm
{
public:
  static vtkDataSetToPiston *New();
  vtkTypeMacro(vtkDataSetToPiston,vtkPistonAlgorithm);
  void PrintSelf(ostream& os, vtkIndent indent);

  // Description:
  // Set/Get the name of the color array to blend with.
  vtkSetStringMacro(ScalarArrayName);
  vtkGetStringMacro(ScalarArrayName);

  // Description:
  // Set/Get the name of the opacity array to blend with.
  vtkSetStringMacro(OpacityArrayName);
  vtkGetStringMacro(OpacityArrayName);

protected:
  vtkDataSetToPiston();
  ~vtkDataSetToPiston();

  // Description:
  // Method that does the actual calculation. Funnels down to ExecuteData.
  virtual int RequestData(vtkInformation* request,
                          vtkInformationVector** inputVector,
                          vtkInformationVector* outputVector);

  // Description:
  // Overridden to say that we require vtkDataSet inputs
  virtual int FillInputPortInformation(int, vtkInformation*);

  char *ScalarArrayName;
  char *OpacityArrayName;

private:
  vtkDataSetToPiston(const vtkDataSetToPiston&);  // Not implemented.
  void operator=(const vtkDataSetToPiston&);  // Not implemented.
};

#endif
