unit PanamahSDK.Log;

interface

uses
  SysUtils, Classes, SyncObjs, Windows;

type

  TPanamahLogger = class
  public
    class procedure Log(const AMessage: string);
  end;

var
  PanamahLogCriticalSection: TCriticalSection;

implementation

{ TPanamahLog }

class procedure TPanamahLogger.Log(const AMessage: string);
var
  LogFilename: string;
  LogFile: TextFile;
begin
  {$IFDEF PANAMAHSDK_LOG}
  PanamahLogCriticalSection.Acquire;
  try
    LogFilename := GetCurrentDir + '\panamah_sdk.log';
    AssignFile(LogFile, LogFilename);
    try
      if FileExists(LogFilename) then
        Append(LogFile)
      else
        Rewrite(LogFile);
      WriteLn(LogFile, Format('[%s thread %d] %s', [FormatDateTime('dd/mm/yyyy hh:nn:ss', Now), GetCurrentThreadId, AMessage]));
    finally
      CloseFile(LogFile);
    end;
  finally
    PanamahLogCriticalSection.Release;
  end;
  {$ENDIF}
end;

initialization
  PanamahLogCriticalSection := TCriticalSection.Create;

finalization
  PanamahLogCriticalSection.Free;

end.
