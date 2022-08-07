unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, EditBtn,
  StdCtrls, Buttons, ExtCtrls, Process, DefaultTranslator, IniPropStorage;

type

  { TMainForm }

  TMainForm = class(TForm)
    Bevel1: TBevel;
    CloneCheckBox: TCheckBox;
    CompressBtn: TButton;
    CloneEdit: TEdit;
    EditButton2: TEditButton;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    OpenDialog1: TOpenDialog;
    Timer1: TTimer;
    Timer2: TTimer;
    procedure CloneCheckBoxChange(Sender: TObject);
    procedure CompressBtnClick(Sender: TObject);
    procedure EditButton1ButtonClick(Sender: TObject);
    procedure EditButton2ButtonClick(Sender: TObject);
    procedure EditButton2KeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartProcess(command, terminal: string);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);

  private

  public

  end;

//Ресурсы перевода
resourcestring
  SWarning1 = 'The user "';
  SWarning2 = '" is not in groups "disk", "vboxusers" and "vboxsf"' +
    #13#10 + #13#10 + 'Run the command in terminal (su/password):' +
    #13#10 + 'usermod -a -G disk,vboxusers,vboxsf $USER' + #13#10 +
    #13#10 + '...and reboot your computer to apply privileges!';
  SCompress = 'Compress';
  SCompletion = 'Completion...';
  SFileNotFound = 'The *.vdi file not found!';
  SCompressionWarning = 'Do not close the window! Wait for the end of the process!';

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

//Определяем вхождение $USER в группы disk и vboxusers
function UserInGroups: boolean;
var
  S: TStringList;
  ExProcess: TProcess;
begin
  S := TStringList.Create;

  ExProcess := TProcess.Create(nil);
  Screen.Cursor := crHourGlass;
  try
    ExProcess.Executable := 'bash';
    ExProcess.Options := ExProcess.Options + [poUsePipes, poWaitOnExit];
    ExProcess.Parameters.Add('-c');

    ExProcess.Parameters.Add('groups | grep "disk" | grep "vboxusers" | grep "vboxsf"');

    ExProcess.Execute;

    S.LoadFromStream(ExProcess.Output);

    if S.Count > 0 then
      Result := True
    else
      Result := False;

  finally
    S.Free;
    ExProcess.Free;
    Screen.Cursor := crDefault;
  end;
end;

//Общая процедура запуска команд
procedure TMainForm.StartProcess(command, terminal: string);
var
  ExProcess: TProcess;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := terminal;  //bash или xterm
    if terminal <> 'bash' then
    begin
      ExProcess.Parameters.Add('-xrm');
      ExProcess.Parameters.Add('XTerm*allowTitleOps:false');
      ExProcess.Parameters.Add('-xrm');
      ExProcess.Parameters.Add('XTerm*cursorColor:red');
      ExProcess.Parameters.Add('-xrm');
      ExProcess.Parameters.Add('XTerm*cursorBlink:true');

      ExProcess.Parameters.Add('-fa');
      ExProcess.Parameters.Add('monospace');
      ExProcess.Parameters.Add('-fs');
      ExProcess.Parameters.Add('9');

      ExProcess.Parameters.Add('-T');
      ExProcess.Parameters.Add(SCompressionWarning);

      ExProcess.Parameters.Add('-g');
      ExProcess.Parameters.Add('85x8+' + IntToStr(MainForm.Left) +
        '+' + IntToStr(MainForm.Top + MainForm.Height + 40));

      ExProcess.Parameters.Add('-e');
    end
    else
      ExProcess.Parameters.Add('-c');

    ExProcess.Parameters.Add(command);
    // ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
    Screen.Cursor := crDefault;
  end;
end;

//Контроль размера файлов
procedure TMainForm.Timer2Timer(Sender: TObject);
var
  S: ansistring;
begin
  //Входной файл *.vdi
  if FileExists(EditButton2.Text) then
  begin
    RunCommand('/bin/bash', ['-c', 'du -sm "' + EditButton2.Text +
      '"' + ' | awk ' + '''' + '{ print $1 }' + ''''], S);
    Label3.Caption := Trim(S);
  end
  else
    Label3.Caption := '0';

  //Выходной файл *-Clone.vdi
  if FileExists(CloneEdit.Text) then
  begin
    RunCommand('/bin/bash', ['-c', 'du -sm "' + CloneEdit.Text +
      '"' + ' | awk ' + '''' + '{ print $1 }' + ''''], S);
    Label5.Caption := Trim(S);
  end
  else
    Label5.Caption := '0';
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  S, V: ansistring;
begin
  RunCommand('/bin/bash', ['-c', 'pidof xterm'], S);
  RunCommand('/bin/bash', ['-c', 'pidof VBoxSVC'], V);

  if (S = '') and (V <> '') then
  begin
    CompressBtn.Caption := SCompletion;
    if RunCommand('/bin/bash', ['-c', 'killall VBoxSVC'], S) then
      CompressBtn.Enabled := False;
  end
  else
  if (S = '') and (V = '') then
  begin
    Timer1.Enabled := False;
    CompressBtn.Caption := SCompress;
    CompressBtn.Enabled := True;
  end;
end;

procedure TMainForm.EditButton1ButtonClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    EditButton2.Text := OpenDialog1.FileName;
end;

procedure TMainForm.CompressBtnClick(Sender: TObject);
var
  Str: TStringList;
begin
  //Файл существует?
  if not FileExists(EditButton2.Text) then
  begin
    MessageDlg(SFileNotFound, mtWarning, [mbOK], 0);
    Exit;
  end;

  //Проверяем вхождение $USER в группы disk и vboxusers
  if not UserInGroups then
  begin
    MessageDlg(SWarning1 + GetEnvironmentVariable('USER') + SWarning2,
      mtWarning, [mbOK], 0);
    Exit;
  end;

  //Создаём пускач компрессии
  Str := TStringList.Create;
  Str.Add('#!/bin/bash');
  Str.Add('');

  if not CloneCheckBox.Checked then
    Str.Add('VBoxManage modifymedium "' + EditButton2.Text + '" --compact')
  else
  begin
    //Удаляем из списка знакомых носителей, чтобы не писать UUID повторно
    StartProcess('if [[ -n $(VBoxManage list hdds | grep "' +
      EditButton2.Text + '-Сlone.vdi") ]]; then VBoxManage closemedium "' +
      EditButton2.Text + '-Clone.vdi"; fi', 'bash');

    //Удаляем результат работы предыдущей сессии
    Str.Add('rm -f "' + ExtractFilePath(EditButton2.Text) + '"*-Сlone.vdi');

    //Получаем UUID оригинального диска VM
    Str.Add('HDUUID=$(VBoxManage showhdinfo "' + EditButton2.Text +
      '" | grep "UUID:" | head -n1 | awk ' + '''' + '{ print $2 }' + '''' + ')');

    //Клонируем в DiskName.vdi-Clone.vdi
    Str.Add('VBoxManage clonemedium "' + EditButton2.Text + '" "' +
      EditButton2.Text + '"-Сlone.vdi --format VDI');

    //Присваиваем родной UUID диску-клону
    Str.Add('VBoxManage internalcommands sethduuid "' + EditButton2.Text +
      '-Сlone.vdi" $HDUUID');

    //Удаляем из списка знакомых носителей, чтобы не писать UUID повторно
    Str.Add('if [[ -n $(VBoxManage list hdds | grep "' + EditButton2.Text +
      '-Сlone.vdi") ]]; then');

    Str.Add(Concat('VBoxManage closemedium disk "', EditButton2.Text,
      '-Сlone.vdi"; fi'));
  end;

  Str.SaveToFile(GetEnvironmentVariable('HOME') + '/.config/vdicomp/compress.sh');
  Str.Free;

  //Делаем пускач исполняемым
  StartProcess('chmod +x ' + GetEnvironmentVariable('HOME') +
    '/.config/vdicomp/compress.sh', 'bash');

  //Запускаем компрессию
  StartProcess(GetEnvironmentVariable('HOME') + '/.config/vdicomp/compress.sh',
    'xterm');

  //Запуск опроса состояния
  CompressBtn.Enabled := False;
  Timer1.Enabled := True;
end;

procedure TMainForm.CloneCheckBoxChange(Sender: TObject);
begin
  if CloneCheckBox.Checked and (EditButton2.Text <> '') then
    CloneEdit.Text := EditButton2.Text + '-Сlone.vdi'
  else
    CloneEdit.Text := '...';
end;

procedure TMainForm.EditButton2ButtonClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    EditButton2.Text := OpenDialog1.FileName;

    if CloneCheckBox.Checked then
      CloneEdit.Text := EditButton2.Text + '-Сlone.vdi'
    else
      CloneEdit.Text := '...';
  end;
end;

procedure TMainForm.EditButton2KeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  key := $0;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  StartProcess('if [[ -n $(pidof VBoxSVC) ]]; then killall VBoxSVC; fi', 'bash');
  StartProcess('if [[ -n $(pidof xterm) ]]; then killall xterm; fi', 'bash');
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  //Проверяем рабочий каталог
  if not DirectoryExists(GetEnvironmentVariable('HOME') + '/.config/vdicomp') then
    StartProcess('mkdir -p ~/.config/vdicomp', 'bash');

  IniPropStorage1.IniFileName :=
    GetEnvironmentVariable('HOME') + '/.config/vdicomp/vdicomp.ini';
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  MainForm.Caption := Application.Title;
  CompressBtn.Caption := SCompress;
end;

end.
