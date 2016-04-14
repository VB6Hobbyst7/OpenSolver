VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} FConsole 
   Caption         =   "OpenSolver - Solving Model"
   ClientHeight    =   5070
   ClientLeft      =   0
   ClientTop       =   -10125
   ClientWidth     =   7065
   OleObjectBlob   =   "FConsole.frx":0000
End
Attribute VB_Name = "FConsole"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private pCommand As String
Private pLogPath As String
Private pStartDir As String

Private pExitCode As Long
Private pConsoleOutput As String

#If Mac Then
    Const ConsoleWidth = 584
    Const ConsoleHeight = 500
#Else
    Const ConsoleWidth = 380
    Const ConsoleHeight = 400
#End If

Private Const MinWidth = ConsoleWidth
Private Const MinHeight = 200
Private ResizeStartX As Double
Private ResizeStartY As Double

Private Sub cmdCancel_Click()
    ProcessAbortSignal
End Sub

Private Sub cmdOk_Click()
    ProcessAbortSignal
End Sub

Private Sub txtConsole_KeyDown(ByVal KeyCode As MSForms.ReturnInteger, ByVal Shift As Integer)
    ' Override any escape keypress for the textbox so it doesn't clear the text
    If KeyCode = 27 Then
        KeyCode = 0
        ProcessAbortSignal
    End If
End Sub

' Make the [x] hide the form rather than unload
Private Sub UserForm_QueryClose(Cancel As Integer, CloseMode As Integer)
    ' If CloseMode = vbFormControlMenu then we know the user
    ' clicked the [x] close button or Alt+F4 to close the form.
    If CloseMode = vbFormControlMenu Then
        ProcessAbortSignal
        Cancel = True
    End If
End Sub

Public Sub SetInput(Command As String, LogPath As String, StartDir As String)
    pCommand = Command
    pLogPath = LogPath
    pStartDir = StartDir
End Sub

Public Sub GetOutput(ByRef ExitCode As Long, ByRef ConsoleOutput As String)
    ExitCode = pExitCode
    ConsoleOutput = pConsoleOutput
End Sub

Public Sub AppendText(NewText As String)
    If Len(NewText) > 0 Then
        With Me.txtConsole
            .Locked = False
            .Text = .Text & NewText
            .Locked = True
        End With
    End If
    UpdateElapsedTime
End Sub

Private Sub UpdateElapsedTime()
    Me.lblElapsed.Caption = "Elapsed Time: " & Int(Timer() - OpenSolverExternalCommand.StartTime) & "s"
End Sub

Public Sub MarkCompleted()
    Dim message As String
    If Me.Tag = "Cancelled" Then
        message = "Process cancelled."
    ElseIf pExitCode <> 0 Then
        message = "Process exited abnormally with exit code " & pExitCode & "."
    Else
        message = "Process completed successfully."
    End If
    Me.AppendText vbNewLine & vbNewLine & message
    
    ' Scroll to bottom
    Me.txtConsole.SetFocus
    
    cmdCancel.Enabled = False
    cmdOk.Enabled = True
    cmdOk.SetFocus
End Sub

Private Sub ProcessAbortSignal()
    If cmdCancel.Enabled Then
        Me.Tag = "Cancelled"
    Else
        Me.Hide
    End If
End Sub

Private Sub UserForm_Activate()
    On Error GoTo ErrorHandler  ' Don't let an error propogate out of the execution
    pConsoleOutput = ExecConsole(Me, pCommand, pLogPath, pStartDir, pExitCode)
    Exit Sub
    
ErrorHandler:
    If OpenSolverErrorHandler.ErrNum = OpenSolver_UserCancelledError Then
        Me.Tag = "Aborted"
    Else
        Me.Tag = OpenSolverErrorHandler.ErrMsg
    End If
End Sub

Private Sub UserForm_Initialize()
   AutoLayout
   CenterForm
End Sub

Private Sub AutoLayout()
    AutoFormat Me.Controls
    
    With Me.txtConsole
        #If Mac Then
            .Font.Name = "Menlo Regular"
        #Else
            .Font.Name = "Consolas"
        #End If
        .ForeColor = &HFFFFFF
        .BackColor = &H0
        .MultiLine = True
        .ScrollBars = fmScrollBarsVertical
        .SpecialEffect = fmSpecialEffectEtched
        .Width = ConsoleWidth
        .Height = ConsoleHeight
        .Top = FormMargin
        .Left = FormMargin
    End With
    
    With Me.cmdCancel
        .Caption = "Cancel"
        .Width = FormButtonWidth
        .Cancel = True
        .Enabled = True
    End With
    
    With Me.cmdOk
        .Caption = "OK"
        .Width = FormButtonWidth
        .Cancel = True
        .Enabled = False
    End With
    
    ' Make the label wide enough so that the message is on one line, then use autosize to shrink the width.
    With Me.lblElapsed
        .Caption = "OpenSolver is busy running your optimisation model..."
        .Left = FormMargin
    End With
    
    ' Add resizer
    With lblResizer
        #If Mac Then
            ' Mac labels don't fire MouseMove events correctly
            .Visible = False
        #End If
        .Caption = "o"
        With .Font
            .Name = "Marlett"
            .Charset = 2
            .Size = 10
        End With
        .AutoSize = True
        .MousePointer = fmMousePointerSizeNWSE
        .BackStyle = fmBackStyleTransparent
    End With
    
    ' Set the positions of the form
    UpdateLayout
    
    Me.BackColor = FormBackColor
    Me.Caption = "OpenSolver - Optimisation Running"
End Sub

Private Sub CenterForm()
    Me.Top = CenterFormTop(Me.Height)
    Me.Left = CenterFormLeft(Me.Width)
End Sub

Private Sub UpdateLayout(Optional ChangeX As Single = 0, Optional ChangeY As Single = 0)
    Dim NewWidth As Double, NewHeight As Double
    NewWidth = Max(txtConsole.Width + ChangeX, MinWidth)
    NewHeight = Max(txtConsole.Height + ChangeY, MinHeight)
    
    ' Update based on new width
    txtConsole.Width = NewWidth
    Me.Width = Me.txtConsole.Width + 2 * FormMargin
    Me.cmdCancel.Left = LeftOfForm(Me.Width, Me.cmdCancel.Width) - 1  ' To account for etched effect on textbox
    Me.cmdOk.Left = LeftOf(cmdCancel, Me.cmdOk.Width)
    Me.lblElapsed.Width = Me.cmdOk.Left - Me.txtConsole.Left - FormMargin
    AutoHeight Me.lblElapsed, Me.lblElapsed.Width
    Me.lblResizer.Left = Me.Width - Me.lblResizer.Width
    Me.Width = Me.Width + FormWindowMargin
    
    ' Update based on new height
    txtConsole.Height = NewHeight
    Me.cmdCancel.Top = Below(Me.txtConsole)
    Me.cmdOk.Top = Me.cmdCancel.Top
    Me.lblElapsed.Top = Me.cmdCancel.Top + (Me.cmdCancel.Height - Me.lblElapsed.Height) / 2
    Me.Height = FormHeight(Me.cmdCancel)
    Me.lblResizer.Top = Me.InsideHeight - Me.lblResizer.Height
End Sub

Private Sub lblResizer_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    If Button = 1 Then
        ResizeStartX = X
        ResizeStartY = Y
    End If
End Sub

Private Sub lblResizer_MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    If Button = 1 Then
        #If Mac Then
            ' Mac reports delta already
            UpdateLayout X, Y
        #Else
            UpdateLayout X - ResizeStartX, Y - ResizeStartY
        #End If
    End If
End Sub
