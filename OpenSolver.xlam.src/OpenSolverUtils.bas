Attribute VB_Name = "OpenSolverUtils"
Option Explicit

#If Mac Then
    Public Declare Sub SleepSeconds Lib "libc.dylib" Alias "sleep" (ByVal Seconds As Long)
#Else
    #If VBA7 Then
        Public Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    #Else
        Public Declare Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    #End If
    
    Sub SleepSeconds(Seconds As Long)
        Sleep Seconds * 1000
    End Sub
#End If

Function RemoveSheetNameFromString(s As String, sheet As Worksheet) As String
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          ' Try with workbook name first
          Dim sheetName As String
          sheetName = "'[" & ActiveWorkbook.Name & "]" & Mid(EscapeSheetName(sheet, True), 2)
          If InStr(s, sheetName) Then
              RemoveSheetNameFromString = Replace(s, sheetName, "")
              GoTo ExitFunction
          End If
          
280       sheetName = EscapeSheetName(sheet)
281       If InStr(s, sheetName) Then
282           RemoveSheetNameFromString = Replace(s, sheetName, "")
283           GoTo ExitFunction
284       End If

290       RemoveSheetNameFromString = s

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "RemoveSheetNameFromString") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function RemoveActiveSheetNameFromString(s As String) As String
          RemoveActiveSheetNameFromString = RemoveSheetNameFromString(s, ActiveSheet)
End Function

' Removes a "\n" character from the end of a string
Function StripTrailingNewline(Block As String) As String
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler
          
          If right(Block, Len(vbNewLine)) = vbNewLine Then
              Block = left(Block, Len(Block) - Len(vbNewLine))
          End If
          StripTrailingNewline = Block

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "StripTrailingNewline") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function StripWorksheetNameAndDollars(s As String, currentSheet As Worksheet) As String
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          ' Remove the current worksheet name from a formula, along with any $
586       StripWorksheetNameAndDollars = RemoveSheetNameFromString(s, currentSheet)
588       StripWorksheetNameAndDollars = Replace(StripWorksheetNameAndDollars, "$", "")

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "StripWorksheetNameAndDollars") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function EscapeSheetName(sheet As Worksheet, Optional ForceQuotes As Boolean = False) As String
    EscapeSheetName = sheet.Name
    
    Dim SpecialChar As Variant, NeedsEscaping As Boolean
    NeedsEscaping = False
    For Each SpecialChar In Array("'", "!", "(", ")", "+", "-")
        If InStr(EscapeSheetName, SpecialChar) Then
            NeedsEscaping = True
            Exit For
        End If
    Next SpecialChar

    If NeedsEscaping Then EscapeSheetName = Replace(EscapeSheetName, "'", "''")
    If ForceQuotes Or NeedsEscaping Then EscapeSheetName = "'" & EscapeSheetName & "'"
    
    EscapeSheetName = EscapeSheetName & "!"
End Function

Function ConvertFromCurrentLocale(ByVal s As String) As String
' Convert a formula or a range from the current locale into US locale
          ConvertFromCurrentLocale = ConvertLocale(s, True)
End Function

Function ConvertToCurrentLocale(ByVal s As String) As String
' Convert a formula or a range from US locale into the current locale
          ConvertToCurrentLocale = ConvertLocale(s, False)
End Function

Private Function ConvertLocale(ByVal s As String, ConvertToUS As Boolean) As String
' Convert strings between locales
' This will add a leading "=" if its not already there
' A blank string is returned if any errors occur
' This works by putting the expression into cell A1 on Sheet1 of the add-in!

          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          ' We turn off calculation & hide alerts as we don't want Excel popping up dialogs asking for references to other sheets
          Dim oldCalculation As Long
291       oldCalculation = Application.Calculation
          Dim oldDisplayAlerts As Boolean
292       oldDisplayAlerts = Application.DisplayAlerts

294       s = Trim(s)
          Dim equalsAdded As Boolean
295       If left(s, 1) <> "=" Then
296           s = "=" & s
297           equalsAdded = True
298       End If
299       Application.Calculation = xlCalculationManual
300       Application.DisplayAlerts = False
          
          If ConvertToUS Then
              ' Set FormulaLocal and get Formula
              ThisWorkbook.Sheets(1).Cells(1, 1).FormulaLocal = s
              On Error GoTo DecimalFixer
302           s = ThisWorkbook.Sheets(1).Cells(1, 1).Formula
          Else
              ' Set Formula and get FormulaLocal
              ThisWorkbook.Sheets(1).Cells(1, 1).Formula = s
              s = ThisWorkbook.Sheets(1).Cells(1, 1).FormulaLocal
          End If
          
303       If equalsAdded Then
304           If left(s, 1) = "=" Then s = Mid(s, 2)
305       End If
306       ConvertLocale = s

ExitFunction:
          ThisWorkbook.Sheets(1).Cells(1, 1).Clear
          Application.Calculation = oldCalculation
          Application.DisplayAlerts = oldDisplayAlerts
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

DecimalFixer: 'Ensures decimal character used is correct.
          If Application.DecimalSeparator = "." Then
              s = Replace(s, ".", ",")
              ThisWorkbook.Sheets(1).Cells(1, 1).FormulaLocal = s
          ElseIf Application.DecimalSeparator = "," Then
              s = Replace(s, ",", ".")
              ThisWorkbook.Sheets(1).Cells(1, 1).FormulaLocal = s
          End If
          Resume

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "ConvertFromCurrentLocale") Then Resume
          RaiseError = True
          ConvertLocale = ""
          GoTo ExitFunction
End Function

Sub PopulateSolverParameters(Solver As String, sheet As Worksheet, SolverParameters As Dictionary, SolveOptions As SolveOptionsType)
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler
          
          ' First we fill all info from the SolveOptions. These can then be overridden by the parameters defined on the sheet
          With SolveOptions
              If UsesPrecision(Solver) Then SolverParameters.Add Key:=PrecisionName(Solver), Item:=.Precision
              If UsesTimeLimit(Solver) Then SolverParameters.Add Key:=TimeLimitName(Solver), Item:=.MaxTime
              If UsesIterationLimit(Solver) Then SolverParameters.Add Key:=IterationLimitName(Solver), Item:=.MaxIterations
              If UsesTolerance(Solver) Then SolverParameters.Add Key:=ToleranceName(Solver), Item:=.Tolerance
          End With
          
          ' The user can define a set of parameters they want to pass to the solver; this gets them as a dictionary. MUST be on the current sheet
          Dim ParametersRange As Range, i As Long
6104      Set ParametersRange = GetSolverParameters(Solver, sheet:=sheet)
          If Not ParametersRange Is Nothing Then
6105          If ParametersRange.Columns.Count <> 2 Then
6106              Err.Raise OpenSolver_SolveError, Description:="The range OpenSolver_" & Solver & "Parameters must be a two-column table."
6108          End If
6109          For i = 1 To ParametersRange.Rows.Count
                  Dim ParamName As String, ParamValue As String
6110              ParamName = Trim(ParametersRange.Cells(i, 1))
6111              If ParamName <> "" Then
6112                  ParamValue = ConvertFromCurrentLocale(Trim(ParametersRange.Cells(i, 2)))
6114                  SolverParameters.Add Key:=ParamName, Item:=ParamValue
6115              End If
6116          Next i
6117      End If

ExitSub:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Sub

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "PopulateSolverParameters") Then Resume
          RaiseError = True
          GoTo ExitSub
End Sub

Function ParametersToKwargs(SolverParameters As Dictionary) As String
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          Dim Key As Variant, result As String
          For Each Key In SolverParameters.Keys
              result = result & Key & "=" & StrExNoPlus(SolverParameters.Item(Key)) & " "
          Next Key
          ParametersToKwargs = Trim(result)

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "ParametersToKwargs") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function ParametersToFlags(SolverParameters As Dictionary) As String
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          Dim Key As Variant, result As String
          For Each Key In SolverParameters.Keys
              result = result & IIf(left(Key, 1) <> "-", "-", "") & Key & " " & StrExNoPlus(SolverParameters.Item(Key)) & " "
          Next Key
          ParametersToFlags = Trim(result)

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "ParametersToFlags") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function ParametersToOptionsFileString(SolverParameters As Dictionary) As String
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler
          
          Dim Key As Variant, result As String
          For Each Key In SolverParameters.Keys
              result = result & Key & " " & StrExNoPlus(SolverParameters.Item(Key)) & vbNewLine
          Next Key
          
          ParametersToOptionsFileString = StripTrailingNewline(result)
          
ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "ParametersToOptionsFileString") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Sub GetSolveOptions(sheet As Worksheet, SolveOptions As SolveOptionsType)
          ' Get the Solver Options, stored in named ranges with values such as "=0.12"
          ' Because these are NAMEs, they are always in English, not the local language, so get their value using Val
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

416       SetAnyMissingDefaultSolverOptions ' This can happen if they have created the model using an old version of OpenSolver
417       With SolveOptions
418           .MaxTime = GetMaxTime(sheet:=sheet)
419           .MaxIterations = GetMaxIterations(sheet:=sheet)
420           .Precision = GetPrecision(sheet:=sheet)
421           .Tolerance = GetTolerance(sheet:=sheet)  ' Stored as a value between 0 and 1 (representing a percentage)
422           .ShowIterationResults = GetShowSolverProgress(sheet:=sheet)
423       End With

ExitSub:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Sub

ErrorHandler:
          On Error Resume Next
          Err.Raise OpenSolver_SolveError, Description:="No Solve options (such as Tolerance) could be found - perhaps a model has not been defined on this sheet?"
          If Not ReportError("OpenSolverUtils", "GetSolveOptions") Then Resume
          RaiseError = True
          GoTo ExitSub
End Sub

Function ValidLPFileVarName(s As String)
' http://lpsolve.sourceforge.net/5.5/CPLEX-format.htm
' The letter E or e, alone or followed by other valid symbols, or followed by another E or e, should be avoided as this notation is reserved for exponential entries. Thus, variables cannot be named e9, E-24, E8cats, or other names that could be interpreted as an exponent. Even variable names such as eels or example can cause a read error, depending on their placement in an input line.
338       If left(s, 1) = "E" Then
339           ValidLPFileVarName = "_" & s
340       Else
341           ValidLPFileVarName = s
342       End If
End Function

Function Max(ParamArray Vals() As Variant) As Variant
          Max = Vals(LBound(Vals))
          
          Dim i As Long
          For i = LBound(Vals) + 1 To UBound(Vals)
482           If Vals(i) > Max Then
483               Max = Vals(i)
486           End If
          Next i
End Function

Function Create1x1Array(X As Variant) As Variant
          ' Create a 1x1 array containing the value x
          Dim v(1, 1) As Variant
492       v(1, 1) = X
493       Create1x1Array = v
End Function

Function ForceCalculate(prompt As String, Optional MinimiseUserInteraction As Boolean = False) As Boolean
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          #If Mac Then
              'In Excel 2011 the Application.CalculationState is not included:
              'http://sysmod.wordpress.com/2011/10/24/more-differences-mainly-vba/
              'Try calling 'Calculate' two times just to be safe? This will probably cause problems down the line, maybe Office 2014 will fix it?
494           Application.Calculate
495           Application.Calculate
496           ForceCalculate = True
          #Else
              'There appears to be a bug in Excel 2010 where the .Calculate does not always complete. We handle up to 3 such failures.
              ' We have seen this problem arise on large models.
497           Application.Calculate
498           If Application.CalculationState <> xlDone Then
499               Application.Calculate
                  Dim i As Long
500               For i = 1 To 10
501                   DoEvents
502                   Sleep (100)
503               Next i
504           End If
505           If Application.CalculationState <> xlDone Then Application.Calculate
506           If Application.CalculationState <> xlDone Then
507               DoEvents
508               Application.CalculateFullRebuild
509               DoEvents
510           End If
          
              ' Check for circular references causing problems, which can happen if iterative calculation mode is enabled.
511           If Application.CalculationState <> xlDone Then
512               If Application.Iteration Then
513                   If MinimiseUserInteraction Then
514                       Application.Iteration = False
515                       Application.Calculate
516                   ElseIf MsgBox("Iterative calculation mode is enabled and may be interfering with the inital calculation. " & _
                                    "Would you like to try disabling iterative calculation mode to see if this fixes the problem?", _
                                    vbYesNo, _
                                    "OpenSolver: Iterative Calculation Mode Detected...") = vbYes Then
517                       Application.Iteration = False
518                       Application.Calculate
519                   End If
520               End If
521           End If
          
522           While Application.CalculationState <> xlDone
523               If MinimiseUserInteraction Then
524                   ForceCalculate = False
525                   GoTo ExitFunction
526               ElseIf MsgBox(prompt, _
                                vbCritical + vbRetryCancel + vbDefaultButton1, _
                                "OpenSolver: Calculation Error Occured...") = vbCancel Then
527                   ForceCalculate = False
528                   GoTo ExitFunction
529               Else 'Recalculate the workbook if the user wants to retry
530                   Application.Calculate
531               End If
532           Wend
533           ForceCalculate = True
          #End If

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "ForceCalculate") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Sub WriteToFile(intFileNum As Long, strData As String, Optional numSpaces As Long = 0, Optional AbortIfBlank As Boolean = False)
' Writes a string to the given file number, adds a newline, and number of spaces to front if specified
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          If Len(strData) = 0 And AbortIfBlank Then GoTo ExitSub
781       Print #intFileNum, Space(numSpaces) & strData

ExitSub:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Sub

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "WriteToFile") Then Resume
          RaiseError = True
          GoTo ExitSub
End Sub

Function MakeSpacesNonBreaking(Text As String) As String
' Replaces all spaces with NBSP char
784       MakeSpacesNonBreaking = Replace(Text, Chr(32), Chr(NBSP))
End Function

Function StripNonBreakingSpaces(Text As String) As String
' Replaces all spaces with NBSP char
784       StripNonBreakingSpaces = Replace(Text, Chr(NBSP), Chr(32))
End Function

Function TrimBlankLines(s As String) As String
' Remove any blank lines at the beginning or end of s
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          Dim Done As Boolean, NewLineSize As Integer
          NewLineSize = Len(vbNewLine)
611       While Not Done
612           If Len(s) < NewLineSize Then
613               Done = True
614           ElseIf left(s, NewLineSize) = vbNewLine Then
615              s = Mid(s, NewLineSize + 1)
616           Else
617               Done = True
618           End If
619       Wend
620       Done = False
621       While Not Done
622           If Len(s) < NewLineSize Then
623               Done = True
624           ElseIf right(s, NewLineSize) = vbNewLine Then
625              s = left(s, Len(s) - NewLineSize)
626           Else
627               Done = True
628           End If
629       Wend
630       TrimBlankLines = s

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "TrimBlankLines") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function IsZero(num As Double) As Boolean
' Returns true if a number is zero (within tolerance)
785       IsZero = IIf(Abs(num) < OpenSolver.EPSILON, True, False)
End Function

Function ZeroIfSmall(value As Double) As Double
          ZeroIfSmall = IIf(IsZero(value), 0, value)
End Function

Function StrEx(d As Double, Optional AddSign As Boolean = True) As String
' Convert a double to a string, always with a + or -. Also ensure we have "0.", not just "." for values between -1 and 1
              Dim s As String, prependedZero As String
1912          s = Mid(str(d), 2)  ' remove the initial space (reserved by VB for the sign)
1913          prependedZero = IIf(left(s, 1) = ".", "0", "")  ' ensure we have "0.", not just "."
1915          StrEx = prependedZero + s
              If AddSign Or d < 0 Then StrEx = IIf(d >= 0, "+", "-") & StrEx
End Function

Function StrExNoPlus(d As Double) As String
    StrExNoPlus = StrEx(d, False)
End Function

Function IsAmericanNumber(s As String, Optional i As Long = 1) As Boolean
          ' Check this is a number like 3.45  or +1.23e-34
          ' This does NOT test for regional variations such as 12,34
          ' This code exists because
          '   val("12+3") gives 12 with no error
          '   Assigning a string to a double uses region-specific translation, so x="1,2" works in French
          '   IsNumeric("12,45") is true even on a US English system (and even worse...)
          '   IsNumeric("($1,23,,3.4,,,5,,E67$)")=True! See http://www.eggheadcafe.com/software/aspnet/31496070/another-vba-bug.aspx)

          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          Dim MustBeInteger As Boolean, SeenDot As Boolean, SeenDigit As Boolean
631       MustBeInteger = i > 1   ' We call this a second time after seeing the "E", when only an int is allowed
632       IsAmericanNumber = False    ' Assume we fail
633       If Len(s) = 0 Then GoTo ExitFunction ' Not a number
634       If Mid(s, i, 1) = "+" Or Mid(s, i, 1) = "-" Then i = i + 1 ' Skip leading sign
635       For i = i To Len(s)
636           Select Case Asc(Mid(s, i, 1))
              Case Asc("E"), Asc("e")
637               If MustBeInteger Or Not SeenDigit Then GoTo ExitFunction ' No exponent allowed (as must be a simple integer)
638               IsAmericanNumber = IsAmericanNumber(s, i + 1)   ' Process an int after the E
639               GoTo ExitFunction
640           Case Asc(".")
641               If SeenDot Then GoTo ExitFunction
642               SeenDot = True
643           Case Asc("0") To Asc("9")
644               SeenDigit = True
645           Case Else
646               GoTo ExitFunction   ' Not a valid char
647           End Select
648       Next i
          ' i As Long, AllowDot As Boolean
649       IsAmericanNumber = SeenDigit

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "IsAmericanNumber") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function SplitWithoutRepeats(StringToSplit As String, Delimiter As String) As String()
' As Split() function, but treats consecutive delimiters as one
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          Dim SplitValues() As String
          SplitValues = Split(StringToSplit, Delimiter)
          ' Remove empty splits caused by consecutive delimiters
          Dim LastNonEmpty As Long, i As Long
          LastNonEmpty = -1
          For i = 0 To UBound(SplitValues)
              If SplitValues(i) <> "" Then
                  LastNonEmpty = LastNonEmpty + 1
                  SplitValues(LastNonEmpty) = SplitValues(i)
              End If
          Next
          ReDim Preserve SplitValues(0 To LastNonEmpty)
          SplitWithoutRepeats = SplitValues

ExitFunction:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Function

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "SplitWithoutRepeats") Then Resume
          RaiseError = True
          GoTo ExitFunction
End Function

Function InStrText(String1 As String, String2 As String)
' Case-insensitive InStr helper
    InStrText = InStr(1, String1, String2, vbTextCompare)
End Function

Public Function TestKeyExists(ByRef col As Collection, Key As String) As Boolean
          On Error GoTo doesntExist:
          Dim Item As Variant
2020      Set Item = col(Key)
2021      TestKeyExists = True
2022      Exit Function
          
doesntExist:
2023      If Err.Number = 5 Then
2024          TestKeyExists = False
2025      Else
2026          TestKeyExists = True
2027      End If
          
End Function

Public Sub OpenURL(URL As String)
          Dim RaiseError As Boolean
          RaiseError = False
          On Error GoTo ErrorHandler

          ThisWorkbook.FollowHyperlink URL

ExitSub:
          If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
          Exit Sub

ErrorHandler:
          If Not ReportError("OpenSolverUtils", "OpenURL") Then Resume
          RaiseError = True
          GoTo ExitSub
End Sub

Public Function URLEncode(StringVal As String, Optional SpaceAsPlus As Boolean = False) As String
    Dim RaiseError As Boolean
    RaiseError = False

    ' Starting in Excel 2013, this function is built in as WorksheetFunction.EncodeURL
    ' We can't include it without causing compilation errors on earlier versions, so we need our own
    
    ' From http://stackoverflow.com/a/218199
    On Error GoTo ErrorHandler
    Dim StringLen As Long: StringLen = Len(StringVal)
    If StringLen > 0 Then
        ReDim result(StringLen) As String
        Dim i As Long, CharCode As Integer
        Dim Char As String, Space As String

        If SpaceAsPlus Then Space = "+" Else Space = "%20"

        For i = 1 To StringLen
            Char = Mid$(StringVal, i, 1)
            CharCode = Asc(Char)
            Select Case CharCode
                Case 97 To 122, 65 To 90, 48 To 57, 45, 46, 95, 126
                    result(i) = Char
                Case 32
                    result(i) = Space
                Case 0 To 15
                    result(i) = "%0" & Hex(CharCode)
                Case Else
                    result(i) = "%" & Hex(CharCode)
            End Select
        Next i
        URLEncode = Join(result, "")
    End If

ExitFunction:
    If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
    Exit Function

ErrorHandler:
    If Not ReportError("OpenSolverUtils", "URLEncode") Then Resume
    RaiseError = True
    GoTo ExitFunction
End Function

Function SystemIs64Bit() As Boolean
          #If Mac Then
              ' Check output of uname -a
              Dim result As String
664           result = ReadExternalCommandOutput("uname -a")
665           SystemIs64Bit = (InStr(result, "x86_64") > 0)
          #Else
              ' Is true if the Windows system is a 64 bit one
              ' If Not Environ("ProgramFiles(x86)") = "" Then Is64Bit=True, or
              ' Is64bit = Len(Environ("ProgramW6432")) > 0; see:
              ' http://blog.johnmuellerbooks.com/2011/06/06/checking-the-vba-environment.aspx and
              ' http://www.mrexcel.com/forum/showthread.php?542727-Determining-If-OS-Is-32-Bit-Or-64-Bit-Using-VBA and
              ' http://stackoverflow.com/questions/6256140/how-to-detect-if-the-computer-is-x32-or-x64 and
              ' http://msdn.microsoft.com/en-us/library/ms684139%28v=vs.85%29.aspx
666           SystemIs64Bit = Environ("ProgramFiles(x86)") <> ""
          #End If
End Function

Function VBAversion() As String
          #If VBA7 Then
3517          VBAversion = "VBA7"
          #ElseIf VBA6 Then
3518          VBAversion = "VBA6"
          #Else
3516          VBAversion = "VBA"
          #End If
End Function

Function ExcelBitness() As String
          #If Win64 Then
3519          ExcelBitness = "64"
          #Else
3520          ExcelBitness = "32"
          #End If
End Function

Function OSFamily() As String
          #If Mac Then
3521          OSFamily = "Mac"
          #Else
3522          OSFamily = "Windows"
          #End If
End Function

Function EnvironmentSummary() As String
3523      EnvironmentSummary = "Version " & sOpenSolverVersion & " (" & sOpenSolverDate & ")" & _
                               " running on " & IIf(SystemIs64Bit, "64", "32") & "-bit " & OSFamily() & _
                               " with " & VBAversion() & " in " & ExcelBitness() & "-bit Excel " & Application.Version
End Function

Function SolverSummary() As String
    ' On separate lines so we can easily step when debugging
    SolverSummary = About_CBC() & vbNewLine & vbNewLine
    SolverSummary = SolverSummary & About_Gurobi() & vbNewLine & vbNewLine
    SolverSummary = SolverSummary & About_NOMAD() & vbNewLine & vbNewLine
    SolverSummary = SolverSummary & About_Bonmin() & vbNewLine & vbNewLine
    SolverSummary = SolverSummary & About_Couenne()
End Function

Sub UpdateStatusBar(Text As String, Optional Force As Boolean = False)
' Function for updating the status bar.
' Saves the last time the bar was updated and won't re-update until a specified amount of time has passed
' The bar can be forced to display the new text regardless of time with the Force argument.
' We only need to toggle ScreenUpdating on Mac
    Dim RaiseError As Boolean
    RaiseError = False
    On Error GoTo ErrorHandler

    #If Mac Then
        Dim ScreenStatus As Boolean
        ScreenStatus = Application.ScreenUpdating
    #End If

    Static LastUpdate As Double
    Dim TimeDiff As Double
    TimeDiff = (Now() - LastUpdate) * 86400  ' Time since last update in seconds
    
    ' Check if last update was long enough ago
    If TimeDiff > 0.5 Or Force Then
        LastUpdate = Now()
        
        #If Mac Then
            Application.ScreenUpdating = True
        #End If

        Application.StatusBar = Text
        DoEvents
    End If

ExitSub:
    #If Mac Then
        Application.ScreenUpdating = ScreenStatus
    #End If
    If RaiseError Then Err.Raise OpenSolverErrorHandler.ErrNum, Description:=OpenSolverErrorHandler.ErrMsg
    Exit Sub

ErrorHandler:
    If Not ReportError("OpenSolverUtils", "UpdateStatusBar") Then Resume
    RaiseError = True
    GoTo ExitSub
End Sub

Public Function MsgBoxEx(ByVal prompt As String, _
                Optional ByVal Options As VbMsgBoxStyle = 0&, _
                Optional ByVal title As String = "OpenSolver", _
                Optional ByVal HelpFile As String, _
                Optional ByVal Context As Long, _
                Optional ByVal LinkTarget As String, _
                Optional ByVal LinkText As String, _
                Optional ByVal MoreDetailsButton As Boolean, _
                Optional ByVal ReportIssueButton As Boolean) _
        As VbMsgBoxResult

    ' Extends MsgBox with extra options:
    ' - First five args are the same as MsgBox, so any MsgBox calls can be swapped to MsgBoxEx
    ' - LinkTarget: a hyperlink will be included above the button if this is set
    ' - LinkText: the display text for the hyperlink. Defaults to the URL if not set
    ' - MoreDetailsButton: Shows a button that opens the error log
    ' - EmailReportButton: Shows a button that prepares an error report email
    
    If Len(LinkText) = 0 Then LinkText = LinkTarget
    
    Dim Button1 As String, Button2 As String, Button3 As String
    Dim Value1 As VbMsgBoxResult, Value2 As VbMsgBoxResult, Value3 As VbMsgBoxResult
    
    ' Get button types
    Select Case Options Mod 8
    Case vbOKOnly
        Button1 = "OK"
        Value1 = vbOK
    Case vbOKCancel
        Button1 = "OK"
        Value1 = vbOK
        Button2 = "Cancel"
        Value2 = vbCancel
    Case vbAbortRetryIgnore
        Button1 = "Abort"
        Value1 = vbAbort
        Button2 = "Retry"
        Value2 = vbRetry
        Button3 = "Ignore"
        Value3 = vbIgnore
    Case vbYesNoCancel
        Button1 = "Yes"
        Value1 = vbYes
        Button2 = "No"
        Value2 = vbNo
        Button3 = "Cancel"
        Value3 = vbCancel
    Case vbYesNo
        Button1 = "Yes"
        Value1 = vbYes
        Button2 = "No"
        Value2 = vbNo
    Case vbRetryCancel
        Button1 = "Retry"
        Value1 = vbRetry
        Button2 = "Cancel"
        Value2 = vbCancel
    End Select
    
    With New frmMsgBoxEx
        .cmdMoreDetails.Visible = MoreDetailsButton
        .cmdReportIssue.Visible = ReportIssueButton
    
        ' Set up buttons
        .cmdButton1.Caption = Button1
        .cmdButton2.Caption = Button2
        .cmdButton3.Caption = Button3
        .cmdButton1.Tag = Value1
        .cmdButton2.Tag = Value2
        .cmdButton3.Tag = Value3
        
        ' Get default button
        Select Case (Options / 256) Mod 4
        Case vbDefaultButton1 / 256
            .cmdButton1.SetFocus
        Case vbDefaultButton2 / 256
            .cmdButton2.SetFocus
        Case vbDefaultButton3 / 256
            .cmdButton3.SetFocus
        End Select
        ' Adjust default button if specified default is going to be hidden
        If .ActiveControl.Tag = "0" Then .cmdButton1.SetFocus
    
        ' We need to unlock the textbox before writing to it on Mac
        .txtMessage.Locked = False
        .txtMessage.Text = prompt
        .txtMessage.Locked = True
    
        .lblLink.Caption = LinkText
        .lblLink.ControlTipText = LinkTarget
    
        .Caption = title
        
        .Show
     
        ' If form was closed using [X], then it was also unloaded, so we set the default to vbCancel
        MsgBoxEx = vbCancel
        On Error Resume Next
        MsgBoxEx = CInt(.Tag)
        On Error GoTo 0
    End With
End Function



