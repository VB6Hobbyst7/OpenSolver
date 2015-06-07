Attribute VB_Name = "OpenSolverAPI"
Option Explicit

Public Const sOpenSolverVersion As String = "2.6.1"
Public Const sOpenSolverDate As String = "2015.02.15"

'/**
' * Solves the OpenSolver model on the current sheet.
' * @param {} SolveRelaxation If True, all integer and boolean constraints will be relaxed to allow continuous values for these variables. Defaults to False
' * @param {} MinimiseUserInteraction If True, all dialogs and messages will be suppressed. Use this when automating a lot of solves so that there are no interruptions. Defaults to False
' * @param {} LinearityCheckOffset Sets the base value used for checking if the model is linear. Change this if a non-linear model is not being detected as non-linear. Defaults to 0
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function RunOpenSolver(Optional SolveRelaxation As Boolean = False, _
                              Optional MinimiseUserInteraction As Boolean = False, _
                              Optional LinearityCheckOffset As Double = 0, _
                              Optional book As Workbook, _
                              Optional sheet As Worksheet) As OpenSolverResult
    ClearError
    On Error GoTo ErrorHandler
    
    GetActiveBookAndSheetIfMissing book, sheet

    RunOpenSolver = OpenSolverResult.Unsolved
    Dim OpenSolver As COpenSolver
    Set OpenSolver = New COpenSolver

    OpenSolver.BuildModelFromSolverData LinearityCheckOffset, MinimiseUserInteraction, SolveRelaxation, book, sheet
    ' Only proceed with solve if nothing detected while building model
    If OpenSolver.SolveStatus = OpenSolverResult.Unsolved Then
        SolveModel OpenSolver, SolveRelaxation, MinimiseUserInteraction
    End If
    
    RunOpenSolver = OpenSolver.SolveStatus
    If Not MinimiseUserInteraction Then OpenSolver.ReportAnySolutionSubOptimality

ExitFunction:
    Set OpenSolver = Nothing    ' Free any OpenSolver memory used
    Exit Function

ErrorHandler:
    ReportError "OpenSolverAPI", "RunOpenSolver", True, MinimiseUserInteraction
    If OpenSolverErrorHandler.ErrNum = OpenSolver_UserCancelledError Then
        RunOpenSolver = AbortedThruUserAction
    Else
        RunOpenSolver = OpenSolverResult.ErrorOccurred
    End If
    GoTo ExitFunction
End Function

'/**
' * Gets a list of short names for all solvers that can be set
' */
Public Function GetAvailableSolvers() As String()
    GetAvailableSolvers = StringArray("CBC", "Gurobi", "NeosCBC", "Bonmin", "Couenne", "NOMAD", "NeosBon", "NeosCou")
End Function

'/**
' * Gets the short name of the currently selected solver for an OpenSolver model
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetChosenSolver(Optional book As Workbook, Optional sheet As Worksheet) As String
    GetActiveBookAndSheetIfMissing book, sheet
    If Not GetNameValueIfExists(book, EscapeSheetName(sheet) & "OpenSolver_ChosenSolver", GetChosenSolver) Then
        GoTo SetDefault
    End If
    
    ' Check solver is an allowed solver
    On Error GoTo SetDefault
    WorksheetFunction.Match GetChosenSolver, GetAvailableSolvers, 0
    Exit Function
    
SetDefault:
    GetChosenSolver = GetAvailableSolvers()(LBound(GetAvailableSolvers))
    SetChosenSolver GetChosenSolver, book, sheet
End Function

'/**
' * Sets the solver for an OpenSolver model
' * @param {} SolverShortName The short name of the solver to be set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetChosenSolver(SolverShortName As String, Optional book As Workbook, Optional sheet As Worksheet)
    ' Check that a valid solver has been specified
    On Error GoTo SolverNotAllowed
    WorksheetFunction.Match SolverShortName, GetAvailableSolvers, 0
        
    SetNameOnSheet "OpenSolver_ChosenSolver", "=" & SolverShortName, book, sheet
    Exit Sub
    
SolverNotAllowed:
    Err.Raise OpenSolver_ModelError, Description:="The specified solver (" & SolverShortName & ") is not in the list of available solvers. " & _
                                                  "Please see the OpenSolverAPI module for the list of available solvers."
End Sub

'/**
' * Returns the objective cell in an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' * @param {} ValidateObjective If True, throws an error if the model is invalid. Defaults to False
' */
Public Function GetObjectiveFunctionCell(Optional book As Workbook, Optional sheet As Worksheet, Optional ValidateObjective As Boolean = False) As Range
    GetActiveBookAndSheetIfMissing book, sheet
    
    ' Get and check the objective function
    Dim isRangeObj As Boolean, valObj As Double, ObjRefersToError As Boolean, ObjRefersToFormula As Boolean, sRefersToObj As String, objIsMissing As Boolean
    GetNameAsValueOrRange book, EscapeSheetName(sheet) & "solver_opt", objIsMissing, isRangeObj, GetObjectiveFunctionCell, ObjRefersToFormula, ObjRefersToError, sRefersToObj, valObj

    If Not ValidateObjective Then Exit Function

    ' If objMissing is false, but the ObjRange is empty, the objective might be an out of date reference
    If objIsMissing = False And GetObjectiveFunctionCell Is Nothing Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="OpenSolver cannot find the objective ('solver_opt' is out of date). Please re-enter the objective, and try again."
    End If
    ' Objective is corrupted somehow
    If ObjRefersToError Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="The objective is marked #REF!, indicating this cell has been deleted. Please fix the objective, and try again."
    End If
    
    If GetObjectiveFunctionCell Is Nothing Then Exit Function
    
    ' Objective has a value that is not a number
    If VarType(GetObjectiveFunctionCell.Value2) <> vbDouble Then
        If VarType(GetObjectiveFunctionCell.Value2) = vbError Then
            Err.Raise Number:=OpenSolver_BuildError, Description:="The objective cell appears to contain an error. This could have occurred if there is a divide by zero error or if you have used the wrong function (eg #DIV/0! or #VALUE!). Please fix this, and try again."
        Else
            Err.Raise Number:=OpenSolver_BuildError, Description:="The objective cell does not appear to contain a numeric value. Please fix this, and try again."
        End If
    End If
End Function

'/**
' * Returns the objective cell in an OpenSolver model. Throws error if invalid.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetObjectiveFunctionCellWithValidation(Optional book As Workbook, Optional sheet As Worksheet) As Range
    Set GetObjectiveFunctionCellWithValidation = GetObjectiveFunctionCell(book, sheet, True)
End Function

'/**
' * Sets the objective cell in an OpenSolver model.
' * @param {} ObjectiveFunctionCell The cell to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetObjectiveFunctionCell(ObjectiveFunctionCell As Range, Optional book As Workbook, Optional sheet As Worksheet)
    SetNamedRangeIfExists "solver_opt", ObjectiveFunctionCell, book, sheet
End Sub

'/**
' * Returns the objective sense type for an OpenSolver model. Defaults to Minimize if an invalid value is saved.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetObjectiveSense(Optional book As Workbook, Optional sheet As Worksheet) As ObjectiveSenseType
    GetObjectiveSense = GetNamedIntegerWithDefault("solver_typ", book, sheet, ObjectiveSenseType.MinimiseObjective)
    
    ' Check that our integer is a valid value for the enum
    Dim i As Integer
    For i = ObjectiveSenseType.[_First] To ObjectiveSenseType.[_Last]
        If GetObjectiveSense = i Then Exit Function
    Next i
    ' It wasn't in the enum - set default
    GetObjectiveSense = ObjectiveSenseType.MinimiseObjective
    SetObjectiveSense GetObjectiveSense, book, sheet
End Function

'/**
' * Sets the objective sense for an OpenSolver model.
' * @param {} ObjectiveSense The objective sense to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetObjectiveSense(ObjectiveSense As ObjectiveSenseType, Optional book As Workbook, Optional sheet As Worksheet)
    SetIntegerNameOnSheet "solver_typ", ObjectiveSense, book, sheet
End Sub

'/**
' * Returns the target objective value in an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetObjectiveTargetValue(Optional book As Workbook, Optional sheet As Worksheet) As Double
    GetObjectiveTargetValue = GetNamedDoubleWithDefault("solver_val", book, sheet, 0)
End Function

'/**
' * Sets the target objective value in an OpenSolver model.
' * @param {} ObjectiveTargetValue The target value to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetObjectiveTargetValue(ObjectiveTargetValue As Double, Optional book As Workbook, Optional sheet As Worksheet)
    SetDoubleNameOnSheet "solver_val", ObjectiveTargetValue, book, sheet
End Sub

'/**
' * Gets the adjustable cells for an OpenSolver model, throwing an error if unset/invalid.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetDecisionVariables(Optional book As Workbook, Optional sheet As Worksheet) As Range
' We check to see if a model exists by getting the adjustable cells. We check for a name first, as this may contain =Sheet1!$C$2:$E$2,Sheet1!#REF!
    GetActiveBookAndSheetIfMissing book, sheet
    
    Dim n As Name
    If Not NameExistsInWorkbook(book, EscapeSheetName(sheet) & "solver_adj", n) Then
        Err.Raise Number:=OpenSolver_ModelError, Description:="No Solver model with decision variables was found on sheet " & sheet.Name
    End If
    
    GetNamedRangeIfExistsOnSheet sheet, "solver_adj", GetDecisionVariables
    If GetDecisionVariables Is Nothing Then
        Err.Raise OpenSolver_ModelError, Description:="A model was found on the sheet " & sheet.Name & " but the decision variable cells (" & n & ") could not be interpreted. Please redefine the decision variable cells, and try again."
    End If
End Function

'/**
' * Gets the adjustable cells range (returning Nothing if invalid) for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetDecisionVariablesWithDefault(Optional book As Workbook, Optional sheet As Worksheet) As Range
    On Error GoTo SetDefault:
    Set GetDecisionVariablesWithDefault = GetDecisionVariables(book, sheet)
    Exit Function
    
SetDefault:
    Set GetDecisionVariablesWithDefault = Nothing
End Function

'/**
' * Gets the adjustable cells range (with overlap removed) for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetDecisionVariablesNoOverlap(Optional book As Workbook, Optional sheet As Worksheet) As Range
    Set GetDecisionVariablesNoOverlap = RemoveRangeOverlap(GetDecisionVariables(book, sheet))
End Function

'/**
' * Sets the adjustable cells range for an OpenSolver model.
' * @param {} DecisionVariables The range to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetDecisionVariables(DecisionVariables As Range, Optional book As Workbook, Optional sheet As Worksheet)
    SetNamedRangeIfExists "adj", DecisionVariables, book, sheet, True
End Sub

'/**
' * Adds a constraint in an OpenSolver model.
' * @param {} LHSRange The range to set as the constraint LHS
' * @param {} Relation The relation to set for the constraint. If Int/Bin, neither RHSRange nor RHSFormula should be set.
' * @param {} RHSRange Set if the constraint RHS is a cell/range
' * @param {} RHSFormula Set if the constraint RHS is a string formula
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub AddConstraint(LHSRange As Range, Relation As RelationConsts, Optional RHSRange As Range, Optional RHSFormula As String, Optional book As Workbook, Optional sheet As Worksheet)
    Dim NewIndex As Long
    NewIndex = GetNumConstraints(book, sheet) + 1
    UpdateConstraint NewIndex, LHSRange, Relation, RHSRange, RHSFormula, book, sheet
End Sub

'/**
' * Updates an existing constraint in an OpenSolver model.
' * @param {} Index The index of the constraint to update
' * @param {} LHSRange The new range to set as the constraint LHS
' * @param {} Relation The new relation to set for the constraint. If Int/Bin, neither RHSRange nor RHSFormula should be set.
' * @param {} RHSRange Set if the new constraint RHS is a cell/range
' * @param {} RHSFormula Set if the new constraint RHS is a string formula
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub UpdateConstraint(Index As Long, LHSRange As Range, Relation As RelationConsts, Optional RHSRange As Range, Optional RHSFormula As String, Optional book As Workbook, Optional sheet As Worksheet)
    ValidateConstraint LHSRange, Relation, RHSRange, RHSFormula
    
    SetConstraintLhs Index, LHSRange, book, sheet
    SetConstraintRel Index, Relation, book, sheet
    
    Select Case Relation
    Case RelationINT
        RHSFormula = "integer"
    Case RelationBIN
        RHSFormula = "binary"
    Case RelationAllDiff
        RHSFormula = "alldiff"
    End Select
    If left(RHSFormula, 1) <> "=" Then RHSFormula = "=" & RHSFormula
    
    SetConstraintRhs Index, RHSRange, RHSFormula, book, sheet
    
    If Index > GetNumConstraints(book, sheet) Then SetNumConstraints Index, book, sheet
End Sub

'/**
' * Deletes a constraint in an OpenSolver model.
' * @param {} Index The index of the constraint to delete
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub DeleteConstraint(Index As Long, Optional book As Workbook, Optional sheet As Worksheet)
    Dim NumConstraints As Long
    NumConstraints = GetNumConstraints(book, sheet)
    
    If Index > NumConstraints Or Index < 1 Then Exit Sub
    
    ' Shift all the constraints down one position
    Dim i As Long
    For i = Index To NumConstraints - 1
        Dim LHSRange As Range, Relation As RelationConsts, RHSFormula As String, RHSRange As Range, RHSValue As Double, RHSRefersToFormula As Boolean
        Set LHSRange = GetConstraintLhs(i + 1, book, sheet)
        Relation = GetConstraintRel(i + 1, book, sheet)
        Set RHSRange = GetConstraintRhs(i + 1, RHSFormula, RHSValue, RHSRefersToFormula, book, sheet)
        UpdateConstraint i, LHSRange, Relation, RHSRange, RHSFormula, book, sheet
    Next i
    
    DeleteNameOnSheet "lhs" & NumConstraints, book, sheet, True
    DeleteNameOnSheet "rel" & NumConstraints, book, sheet, True
    DeleteNameOnSheet "rhs" & NumConstraints, book, sheet, True
    
    SetNumConstraints NumConstraints - 1, book, sheet
End Sub

'/**
' * Clears an entire OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub ResetModel(Optional book As Workbook, Optional sheet As Worksheet)
    Dim SolverNames() As Variant, OpenSolverNames() As Variant, Name As Variant
    SolverNames = Array("opt", "typ", "adj", "neg", "sho", "rlx", "tol", "tim", "pre", "itr", "num", "val")
    OpenSolverNames = Array("ChosenSolver", "DualsNewSheet", "UpdateSensitivity", "LinearityCheck", "Duals")
    
    For Each Name In SolverNames
        DeleteNameOnSheet CStr(Name), book, sheet, True
    Next Name
    For Each Name In OpenSolverNames
        DeleteNameOnSheet "OpenSolver_" & CStr(Name), book, sheet
    Next Name
End Sub

'/**
' * Returns the number of constraints in an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetNumConstraints(Optional book As Workbook, Optional sheet As Worksheet) As Long
    GetNumConstraints = GetNamedIntegerWithDefault("solver_num", book, sheet, 0)
End Function

'/**
' * Sets the number of constraints in an OpenSolver model. Using Set methods to modify constraints is dangerous, it is best to use Add/Delete/UpdateConstraint.
' * @param {} NumConstraints The number of constraints to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetNumConstraints(NumConstraints As Long, Optional book As Workbook, Optional sheet As Worksheet)
    SetIntegerNameOnSheet "solver_num", NumConstraints, book, sheet
End Sub

'/**
' * Returns the LHS range for a specified constraint in an OpenSolver model.
' * @param {} Index The index of the constraint
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' * @param {} RefersTo Optional. Returns a string representation of the LHS range
' */
Public Function GetConstraintLhs(Index As Long, Optional book As Workbook, Optional sheet As Worksheet, Optional RefersTo As String) As Range
    GetActiveBookAndSheetIfMissing book, sheet
    
    Set GetConstraintLhs = Nothing
    
    Dim IsRange As Boolean, value As Double, RefersToError As Boolean, RefersToFormula As Boolean, IsMissing As Boolean
    GetNameAsValueOrRange book, EscapeSheetName(sheet) & "solver_lhs" & Index, IsMissing, IsRange, GetConstraintLhs, RefersToFormula, RefersToError, RefersTo, value
    ' Must have a left hand side defined
    If IsMissing Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="The left hand side for a constraint does not appear to be defined ('solver_lhs" & Index & " is missing). Please fix this, and try again."
    End If
    ' Must be valid
    If RefersToError Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="The constraints reference cells marked #REF!, indicating these cells have been deleted. Please fix these constraints, and try again."
    End If
    ' LHSs must be ranges
    If Not IsRange Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="A constraint was entered with a left hand side (" & RefersTo & ") that is not a range. Please update the constraint, and try again."
    End If
End Function

'/**
' * Sets the constraint LHS for a specified constraint in an OpenSolver model. Using Set methods to modify constraints is dangerous, it is best to use Add/Delete/UpdateConstraint.
' * @param {} Index The index of the constraint to modify
' * @param {} ConstraintLhs The cell range to set as the constraint LHS
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetConstraintLhs(Index As Long, ConstraintLhs As Range, Optional book As Workbook, Optional sheet As Worksheet)
    SetNamedRangeIfExists "solver_lhs" & Index, ConstraintLhs, book, sheet
End Sub

'/**
' * Returns the relation for a specified constraint in an OpenSolver model.
' * @param {} Index The index of the constraint
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetConstraintRel(Index As Long, Optional book As Workbook, Optional sheet As Worksheet) As RelationConsts
    GetConstraintRel = GetNamedIntegerWithDefault("solver_rel" & Index, book, sheet, RelationConsts.RelationLE)
    
    ' Check that our integer is a valid value for the enum
    Dim i As Integer
    For i = RelationConsts.[_First] To RelationConsts.[_Last]
        If GetConstraintRel = i Then Exit Function
    Next i
    ' It wasn't in the enum - set default
    GetConstraintRel = RelationConsts.RelationLE
    SetConstraintRel Index, GetConstraintRel, book, sheet
End Function

'/**
' * Sets the constraint relation for a specified constraint in an OpenSolver model. Using Set methods to modify constraints is dangerous, it is best to use Add/Delete/UpdateConstraint.
' * @param {} Index The index of the constraint to modify
' * @param {} ConstraintRel The constraint relation to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetConstraintRel(Index As Long, ConstraintRel As RelationConsts, Optional book As Workbook, Optional sheet As Worksheet)
    SetIntegerNameOnSheet "solver_rel" & Index, ConstraintRel, book, sheet
End Sub

'/**
' * Returns the RHS for a specified constraint in an OpenSolver model. The Formula or value parameters will be set if the RHS is not a range (in this case the function returns Nothing).
' * @param {} Index The index of the constraint
' * @param {} Formula Returns the value of the RHS if it is a string formula
' * @param {} value Returns the value of the RHS if it is a constant value
' * @param {} RefersToFormula Set to true if the RHS is a string formula
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetConstraintRhs(Index As Long, Formula As String, value As Double, RefersToFormula As Boolean, Optional book As Workbook, Optional sheet As Worksheet) As Range
    GetActiveBookAndSheetIfMissing book, sheet
    
    Set GetConstraintRhs = Nothing
    
    Dim IsRange As Boolean, RefersToError As Boolean, IsMissing As Boolean
    GetNameAsValueOrRange book, EscapeSheetName(sheet) & "solver_rhs" & Index, IsMissing, IsRange, GetConstraintRhs, RefersToFormula, RefersToError, Formula, value
    ' Must have a right hand side defined
    If IsMissing Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="The right hand side for a constraint does not appear to be defined ('solver_rhs" & Index & " is missing). Please fix this, and try again."
    End If
    ' Must be valid
    If RefersToError Then
        Err.Raise Number:=OpenSolver_BuildError, Description:="The constraints reference cells marked #REF!, indicating these cells have been deleted. Please fix these constraints, and try again."
    End If
End Function

'/**
' * Sets the constraint RHS for a specified constraint in an OpenSolver model. Only one of ConstraintRhsRange and ConstraintRhsFormula should be set, depending on whether the RHS is a range or a string formula. Using Set methods to modify constraints is dangerous, it is best to use Add/Delete/UpdateConstraint.
' * @param {} Index The index of the constraint to modify
' * @param {} ConstraintRhsRange Set if the constraint RHS is a cell range
' * @param {} ConstraintRhsFormula Set if the constraint RHS is a string formula
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetConstraintRhs(Index As Long, ConstraintRhsRange As Range, ConstraintRhsFormula As String, Optional book As Workbook, Optional sheet As Worksheet)
    If ConstraintRhsRange Is Nothing Then
        SetNameOnSheet "rhs" & Index, ConstraintRhsFormula, book, sheet, True
    Else
        SetNamedRangeIfExists "rhs" & Index, ConstraintRhsRange, book, sheet, True
    End If
End Sub

'/**
' * Returns whether unconstrained variables are non-negative for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetNonNegativity(Optional book As Workbook, Optional sheet As Worksheet) As Boolean
    GetNonNegativity = GetNamedIntegerAsBooleanWithDefault("solver_neg", book, sheet, True)
End Function

'/**
' * Sets whether unconstrained variables are non-negative for an OpenSolver model.
' * @param {} NonNegativity True if unconstrained variables should be non-negative
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetNonNegativity(NonNegativity As Boolean, Optional book As Workbook, Optional sheet As Worksheet)
    SetBooleanAsIntegerNameOnSheet "solver_neg", NonNegativity, book, sheet
End Sub

'/**
' * Returns whether a post-solve linearity check will be run for an OpenSolver model
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetLinearityCheck(Optional book As Workbook, Optional sheet As Worksheet) As Boolean
    GetLinearityCheck = GetNamedIntegerAsBooleanWithDefault("OpenSolver_LinearityCheck", book, sheet, True)
End Function

'/**
' * Sets the whether to run a post-solve linearity check for an OpenSolver model.
' * @param {} LinearityCheck True to run linearity check
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetLinearityCheck(LinearityCheck As Boolean, Optional book As Workbook, Optional sheet As Worksheet)
    SetBooleanAsIntegerNameOnSheet "OpenSolver_LinearityCheck", LinearityCheck, book, sheet
End Sub

'/**
' * Returns whether to show solve progress for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetShowSolverProgress(Optional book As Workbook, Optional sheet As Worksheet) As Boolean
    GetShowSolverProgress = GetNamedIntegerAsBooleanWithDefault("solver_sho", book, sheet, False)
End Function

'/**
' * Sets whether to show solve progress for an OpenSolver model.
' * @param {} ShowSolverProgress True to show progress while solving
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetShowSolverProgress(ShowSolverProgress As Boolean, Optional book As Workbook, Optional sheet As Worksheet)
    SetBooleanAsIntegerNameOnSheet "solver_sho", ShowSolverProgress, book, sheet
End Sub

'/**
' * Returns the max solve time for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetMaxTime(Optional book As Workbook, Optional sheet As Worksheet) As Long
    GetMaxTime = GetNamedIntegerWithDefault("solver_tim", book, sheet, 999999999)
End Function

'/**
' * Sets the max solve time for an OpenSolver model.
' * @param {} MaxTime The max solve time in seconds
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetMaxTime(MaxTime As Long, Optional book As Workbook, Optional sheet As Worksheet)
    SetIntegerNameOnSheet "solver_tim", MaxTime, book, sheet
End Sub

'/**
' * Returns solver tolerance (as a double) for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetTolerance(Optional book As Workbook, Optional sheet As Worksheet) As Double
    GetTolerance = GetNamedDoubleWithDefault("solver_tol", book, sheet, 0.05)
End Function

'/**
' * Returns solver tolerance (as a percentage) for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetToleranceAsPercentage(Optional book As Workbook, Optional sheet As Worksheet) As Double
    GetToleranceAsPercentage = GetTolerance(book, sheet) * 100
End Function

'/**
' * Sets solver tolerance for an OpenSolver model.
' * @param {} Tolerance The tolerance to set (between 0 and 1)
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetTolerance(Tolerance As Double, Optional book As Workbook, Optional sheet As Worksheet)
    SetDoubleNameOnSheet "solver_tol", Tolerance, book, sheet
End Sub

'/**
' * Sets the solver tolerance (as a percentage) for an OpenSolver model.
' * @param {} Tolerance The tolerance to set as a percentage (between 0 and 100)
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetToleranceAsPercentage(Tolerance As Double, Optional book As Workbook, Optional sheet As Worksheet)
    SetTolerance Tolerance / 100, book, sheet
End Sub

'/**
' * Returns the solver iteration limit for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetMaxIterations(Optional book As Workbook, Optional sheet As Worksheet) As Long
    GetMaxIterations = GetNamedIntegerWithDefault("solver_itr", book, sheet, 999999999)
End Function

'/**
' * Sets the solver iteration limit for an OpenSolver model.
' * @param {} MaxIterations The iteration limit to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetMaxIterations(MaxIterations As Long, Optional book As Workbook, Optional sheet As Worksheet)
    SetIntegerNameOnSheet "solver_itr", MaxIterations, book, sheet
End Sub

'/**
' * Returns the solver precision for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetPrecision(Optional book As Workbook, Optional sheet As Worksheet) As Double
    GetPrecision = GetNamedDoubleWithDefault("solver_pre", book, sheet, 0.000001)
End Function

'/**
' * Sets the solver precision for an OpenSolver model.
' * @param {} Precision The solver precision to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetPrecision(Precision As Double, Optional book As Workbook, Optional sheet As Worksheet)
    SetDoubleNameOnSheet "solver_pre", Precision, book, sheet
End Sub

'/**
' * Returns 'Extra Solver Parameters' range for specified solver in an OpenSolver model.
' * @param {} SolverShortName The short name of the solver for which parameters are being returned
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetSolverParameters(SolverShortName As String, Optional book As Workbook, Optional sheet As Worksheet) As Range
    If Not GetNamedRangeIfExistsOnSheet(sheet, "OpenSolver_" & SolverShortName & "Parameters", GetSolverParameters) Then Set GetSolverParameters = Nothing
End Function

'/**
' * Sets 'Extra Parameters' range for a specified solver in an OpenSolver model.
' * @param {} SolverShortName The short name of the solver for which parameters are being set
' * @param {} SolverParameters The range containing the parameters (must be a range with two columns: keys and parameters)
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetSolverParameters(SolverShortName As String, SolverParameters As Range, Optional book As Workbook, Optional sheet As Worksheet)
    ValidateParametersRange SolverParameters
    SetNamedRangeIfExists "OpenSolver_" & SolverShortName & "Parameters", SolverParameters, book, sheet
End Sub

'/**
' * Deletes 'Extra Parameters' range for a specified solver in an OpenSolver model.
' * @param {} SolverShortName The short name of the solver for which parameters are deleted
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub DeleteSolverParameters(SolverShortName As String, Optional book As Workbook, Optional sheet As Worksheet)
    SetSolverParameters SolverShortName, Nothing, book, sheet
End Sub

'/**
' * Returns whether Solver's 'ignore integer constraints' option is set for an OpenSolver model. OpenSolver cannot solve while this option is enabled.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetIgnoreIntegerConstraints(Optional book As Workbook, Optional sheet As Worksheet) As Boolean
    GetIgnoreIntegerConstraints = GetNamedIntegerAsBooleanWithDefault("solver_rlx", book, sheet, False)
End Function

'/**
' * Sets Solver's 'ignore integer constraints' option for an OpenSolver model. OpenSolver cannot solve while this option is enabled.
' * @param {} IgnoreIntegerConstraints True to turn on 'ignore integer constraints'
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetIgnoreIntegerConstraints(IgnoreIntegerConstraints As Boolean, Optional book As Workbook, Optional sheet As Worksheet)
    SetBooleanAsIntegerNameOnSheet "solver_rlx", IgnoreIntegerConstraints, book, sheet
End Sub

'/**
' * Returns target range for sensitivity analysis output for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetDuals(Optional book As Workbook, Optional sheet As Worksheet) As Range
    If Not GetNamedRangeIfExistsOnSheet(sheet, "OpenSolver_Duals", GetDuals) Then Set GetDuals = Nothing
End Function

'/**
' * Sets target range for sensitivity analysis output for an OpenSolver model.
' * @param {} Duals The target range for output (Nothing for no sensitivity analysis)
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetDuals(Duals As Range, Optional book As Workbook, Optional sheet As Worksheet)
    SetNamedRangeIfExists "OpenSolver_Duals", Duals, book, sheet
End Sub

'/**
' * Returns whether 'Output sensitivity analysis' is set for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetDualsOnSheet(Optional book As Workbook, Optional sheet As Worksheet) As Boolean
    GetDualsOnSheet = GetNamedBooleanWithDefault("OpenSolver_DualsNewSheet", book, sheet, False)
End Function

'/**
' * Sets the value of 'Output sensitivity analysis' for an OpenSolver model.
' * @param {} DualsOnSheet True to set 'Output sensitivity analysis'
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetDualsOnSheet(DualsOnSheet As Boolean, Optional book As Workbook, Optional sheet As Worksheet)
    SetBooleanNameOnSheet "OpenSolver_DualsNewSheet", DualsOnSheet, book, sheet
End Sub

'/**
' * Returns True if 'Output sensitivity analysis' destination is set to 'updating any previous sheet' for an OpenSolver model, and False if set to 'on a new sheet'.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Function GetUpdateSensitivity(Optional book As Workbook, Optional sheet As Worksheet) As Boolean
    GetUpdateSensitivity = GetNamedBooleanWithDefault("OpenSolver_UpdateSensitivity", book, sheet, True)
End Function

'/**
' * Sets the destination option for 'Output sensitivity analysis' for an OpenSolver model.
' * @param {} UpdateSensitivity True to set 'updating any previous sheet'. False to set 'on a new sheet'
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetUpdateSensitivity(UpdateSensitivity As Boolean, Optional book As Workbook, Optional sheet As Worksheet)
    SetBooleanNameOnSheet "OpenSolver_UpdateSensitivity", UpdateSensitivity, book, sheet
End Sub

'/**
' * Gets the QuickSolve parameter range for an OpenSolver model.
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' * @param {} ValidateRange If True, an error will be thrown if no range is set
' */
Public Function GetQuickSolveParameters(Optional book As Workbook, Optional sheet As Worksheet, Optional ValidateRange As Boolean = False) As Range
    If Not GetNamedRangeIfExistsOnSheet(sheet, "OpenSolverModelParameters", GetQuickSolveParameters) Then Set GetQuickSolveParameters = Nothing
    If ValidateRange And GetQuickSolveParameters Is Nothing Then
        Err.Raise OpenSolver_BuildError, Description:="No parameter range could be found on the worksheet. Please use ""Initialize Quick Solve Parameters""" & _
                                                      "to define the cells that you wish to change between successive OpenSolver solves. Note that changes " & _
                                                      "to these cells must lead to changes in the underlying model's right hand side values for its constraints."
    End If
End Function

'/**
' * Sets the QuickSolve parameter range for an OpenSolver model.
' * @param {} QuickSolveParameters The parameter range to set
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub SetQuickSolveParameters(QuickSolveParameters As Range, Optional book As Workbook, Optional sheet As Worksheet)
    SetNamedRangeIfExists "OpenSolverModelParameters", QuickSolveParameters, book, sheet
End Sub

'/**
' * Initializes QuickSolve procedure for an OpenSolver model.
' * @param {} SolveRelaxation If True, all integer and boolean constraints will be relaxed to allow continuous values for these variables. Defaults to False
' * @param {} MinimiseUserInteraction If True, all dialogs and messages will be suppressed. Use this when automating a lot of solves so that there are no interruptions. Defaults to False
' * @param {} LinearityCheckOffset Sets the base value used for checking if the model is linear. Change this if a non-linear model is not being detected as non-linear. Defaults to 0
' * @param {} book The workbook containing the model (defaults to active workbook)
' * @param {} sheet The worksheet containing the model (defaults to active worksheet)
' */
Public Sub InitializeQuickSolve(Optional SolveRelaxation As Boolean = False, Optional MinimiseUserInteraction As Boolean = False, Optional LinearityCheckOffset As Double = 0, Optional book As Workbook, Optional sheet As Worksheet)
    ClearError
    On Error GoTo ErrorHandler
    
    GetActiveBookAndSheetIfMissing book, sheet

    If Not CreateSolver(GetChosenSolver(book, sheet)).ModelType = Diff Then
        Err.Raise OpenSolver_ModelError, Description:="The selected solver does not support QuickSolve"
    End If

    Dim ParamRange As Range
    Set ParamRange = GetQuickSolveParameters(book, sheet, True)  ' Throws error if missing
    Set QuickSolver = New COpenSolver
    QuickSolver.BuildModelFromSolverData LinearityCheckOffset, MinimiseUserInteraction, SolveRelaxation, book, sheet
    QuickSolver.InitializeQuickSolve ParamRange

ExitSub:
    Exit Sub

ErrorHandler:
    ReportError "OpenSolverAPI", "InitializeQuickSolve", True, MinimiseUserInteraction
    GoTo ExitSub
End Sub

'/**
' * Runs a QuickSolve for currently initialized QuickSolve model.
' * @param {} MinimiseUserInteraction If True, all dialogs and messages will be suppressed. Use this when automating a lot of solves so that there are no interruptions. Defaults to False
' */
Public Function RunQuickSolve(Optional SolveRelaxation As Boolean = False, Optional MinimiseUserInteraction As Boolean = False) As OpenSolverResult
    ClearError
    On Error GoTo ErrorHandler

    If QuickSolver Is Nothing Then
        Err.Raise OpenSolver_SolveError, Description:="There is no model to solve, and so the quick solve cannot be completed. Please select the Initialize Quick Solve command."
    Else
        QuickSolver.DoQuickSolve SolveRelaxation, MinimiseUserInteraction
        RunQuickSolve = QuickSolver.SolveStatus
    End If

    If Not MinimiseUserInteraction Then QuickSolver.ReportAnySolutionSubOptimality

ExitFunction:
    Exit Function

ErrorHandler:
    ReportError "OpenSolverMain", "RunQuickSolve", True, MinimiseUserInteraction
    If OpenSolverErrorHandler.ErrNum = OpenSolver_UserCancelledError Then
        RunQuickSolve = AbortedThruUserAction
    Else
        RunQuickSolve = OpenSolverResult.ErrorOccurred
    End If
    GoTo ExitFunction
End Function

'/**
' * Clears any initialized QuickSolve.
' */
Public Sub ClearQuickSolve()
    Set QuickSolver = Nothing
End Sub

