VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} frmOptions 
   Caption         =   "OpenSolver - Solve Options"
   ClientHeight    =   3855
   ClientLeft      =   42
   ClientTop       =   378
   ClientWidth     =   4144
   OleObjectBlob   =   "frmOptions.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "frmOptions"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Sub cmdCancel_Click()
41690     Unload Me
End Sub

Private Sub cmdOK_Click()
    frmOptions.OptionsOK Me
    Unload Me
End Sub

Public Sub OptionsOK(f As UserForm)
41700     If f.chkNonNeg.value = True Then
41710         SetSolverNameOnSheet "neg", "=1"
41720     Else
41730         SetSolverNameOnSheet "neg", "=2"     ' 2 means false
41740     End If
          
41750     If f.chkShowSolverProgress.value = True Then
41760         SetSolverNameOnSheet "sho", "=1"
41770     Else
41780         SetSolverNameOnSheet "sho", "=2"     ' 2 means false
41790     End If
          
41870     SetSolverNameOnSheet "tim", "=" & Trim(str(CDbl(f.txtMaxTime.Text)))  ' Trim the leading space which str puts in for +'ve values
41880     SetSolverNameOnSheet "itr", "=" & Trim(str(CDbl(f.txtMaxIter.Text)))  ' Trim the leading space which str puts in for +'ve values
41890     SetSolverNameOnSheet "pre", "=" & Trim(str(CDbl(f.txtPre.Text)))  ' Trim the leading space which str puts in for +'ve values
41900     f.txtTol.Text = Replace(f.txtTol.Text, "%", "")
41910     SetSolverNameOnSheet "tol", "=" & Trim(str(CDbl(f.txtTol.Text) / 100))    ' Str() uses . for decimal
                                                                      ' CDbl respects the locale. We trim the leading space which str puts in for +'ve values
                                                                      
41920     If f.chkPerformLinearityCheck.value = True Then
              ' Default is "do check", so we just delete the option
41930         DeleteNameOnSheet "OpenSolver_LinearityCheck"
41940     Else
              ' Set the name, with a value of 2=off
41950         SetNameOnSheet "OpenSolver_LinearityCheck", "=2"
41960     End If
                                                                      
41970     Unload Me
End Sub

Private Sub UserForm_Activate()
          frmOptions.OptionsActivate Me
End Sub

Public Sub OptionsActivate(f As UserForm)
41980     SetAnyMissingDefaultExcel2007SolverOptions

          Dim nonNeg As Boolean, s As String
          ' nonNeg = True   ' a sensible default
41990     If GetNameValueIfExists(ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!solver_neg", s) Then
42000         nonNeg = s = "1"
42010     End If
          
          Dim ShowSolverProgress As Boolean
          ' ShowSolverProgress = False
42020     If GetNameValueIfExists(ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!solver_sho", s) Then
42030         ShowSolverProgress = s = "1"
42040     End If
          
          Dim maxTime As Double
          ' maxTime = 9999 ' A default value if none is yet defined
42130     GetNamedNumericValueIfExists ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!solver_tim", maxTime
          
          Dim maxIter As Double
42140     GetNamedNumericValueIfExists ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!solver_itr", maxIter

          Dim conPre As Double
42150     GetNamedNumericValueIfExists ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!solver_pre", conPre

          Dim tol As Double
          ' tol = 0.05  ' A default value if none is yet defined
42160     GetNamedNumericValueIfExists ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!solver_tol", tol
          
          ' We perform a linearity check by default unless the defined name exists with value 2=off
          Dim performLinearityCheck As Boolean
42170     performLinearityCheck = True
42180     If GetNameValueIfExists(ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!OpenSolver_LinearityCheck", s) Then
42190         performLinearityCheck = s = "1"
42200     End If

42210     f.chkNonNeg.value = nonNeg
42220     f.chkShowSolverProgress.value = ShowSolverProgress
42240     f.txtMaxTime.Text = CStr(maxTime)
42250     f.txtTol.Text = tol * 100
42260     f.txtMaxIter.Text = CStr(maxIter)
42270     f.txtPre = CStr(conPre)
42280     f.chkPerformLinearityCheck.value = performLinearityCheck

          Dim Solver As String
42290     If Not GetNameValueIfExists(ActiveWorkbook, "'" & Replace(ActiveSheet.Name, "'", "''") & "'!OpenSolver_ChosenSolver", Solver) Then
              Solver = "CBC"
42300         Call SetNameOnSheet("OpenSolver_ChosenSolver", "=" & Solver)
42310     End If

          If SolverType(Solver) = OpenSolver_SolverType.NonLinear Then
              ' Disable linearity options
42820         f.chkPerformLinearityCheck.Enabled = False
42840         f.txtTol.Enabled = False
          End If
          
42850     If Solver <> "NOMAD" Then
              ' Disable NOMAD only options
42860         f.txtMaxIter.Enabled = False
42870         f.txtPre.Enabled = False
42880     End If
End Sub

