unit HttpServerCommand;

interface
uses
  classes, IdContext, IdCustomHTTPServer, generics.collections,
  System.SysUtils;

type
  TRESTCommandClass = class of TRESTCommand;
  THttpServerCommand= class;
  TRESTCommandREG= class;

  TRESTCommand=class
  private
    FParams: TStringList;
    FContext: TIdContext;
    FRequestInfo: TIdHTTPRequestInfo;
    FResponseInfo: TIdHTTPResponseInfo;
    FReg: TRESTCommandREG;
    FStreamContents: String;
    procedure start(AReg: TRESTCommandREG; AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; AParams: TStringList);
    procedure ParseParams(const AURI, AMask:String);
    procedure ReadStream(ARequestInfo: TIdHTTPRequestInfo);
  protected
    procedure execute; virtual;
  public
    constructor create(AServer: THttpServerCommand);
    procedure ResponseJSON(Json: String);
    procedure Error(code: integer);

    destructor Destroy; override;
    property Context: TIdContext read FContext;
    property RequestInfo: TIdHTTPRequestInfo read FRequestInfo;
    property ResponseInfo: TIdHTTPResponseInfo read FResponseInfo;
    property Params: TStringList read FParams;
    property StreamContents : String read FStreamContents;
  end;

  TRESTCommandREG= class
  public
    FTYPE: String;
    FPATH: String;
    FCommand: TRESTCommandClass;
    constructor Create(ATYPE:String; APATH: String; ACommand: TRESTCommandClass);
  end;

  THttpServerCommandRegister=class(TComponent)
  private
    FList: TObjectList<TRESTCommandREG>;
  public
    procedure Register(const ATYPE, APATH: String; ACommand: TRESTCommandClass);
    constructor Create(AOwner: TComponent); override;
    function isUri(const AURI, AMask: String; AParams: TStringList): boolean;
    function FindCommand(ACommand: String; AURI: String; Params: TStringList): TRESTCommandREG;
    destructor Destroy; override;
  end;

  THttpServerCommand= class (TComponent)
  private
    FCommands: THttpServerCommandRegister;
    function TrataCommand(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo): boolean;
    procedure TrataErro(ACmd: TRESTCommandREG;AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo;  E: Exception);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    property Commands: THttpServerCommandRegister read FCommands;
  end;


implementation

uses
  RegularExpressions;

{ THttpServerCommand }
function THttpServerCommand.TrataCommand(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo): boolean;
var
  cmdReg: TRESTCommandREG;
  cmd: TRESTCommand;
  Params: TStringList;
begin
  Params:= TStringList.Create;
  try
    cmdReg:= FCommands.FindCommand(ARequestInfo.Command,ARequestInfo.URI, Params);
    if cmdReg=nil then  exit(false);

    try
      cmd:=cmdReg.FCommand.create(self);
      try
        cmd.start(cmdReg, AContext, ARequestInfo, AResponseInfo, Params);
        cmd.execute;
      finally
        cmd.Free;
      end;
    except
      on e:Exception do
      begin
         TrataErro(cmdReg, AContext, ARequestInfo, AResponseInfo, e);
      end;
    end;
    result:= true;
  finally
    params.Free;
  end;
end;


procedure THttpServerCommand.TrataErro(ACmd: TRESTCommandREG;
  AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; E: Exception);
begin
  AResponseInfo.ResponseNo := 404;
end;

procedure THttpServerCommand.CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  if not TrataCommand(AContext,ARequestInfo,AResponseInfo) then
    AResponseInfo.ResponseNo := 404;
end;

constructor THttpServerCommand.Create(AOwner: TComponent);
begin
  inherited;
  FCommands:= THttpServerCommandRegister.Create(self);
end;

destructor THttpServerCommand.Destroy;
begin
  FCommands.Free;
  inherited;
end;

{ THttpServerCommandRegister }

constructor THttpServerCommandRegister.Create(AOwner: TComponent);
begin
  inherited;
  FList:= TObjectList<TRESTCommandREG>.Create(True);
end;

destructor THttpServerCommandRegister.Destroy;
begin
  FList.Free;
  inherited;
end;

function THttpServerCommandRegister.FindCommand(ACommand, AURI: String; Params: TStringList): TRESTCommandREG;
var
  I: Integer;
begin
  for I := 0 to FList.Count-1 do
  begin
    if SameText(ACommand,FList[i].FTYPE) then
    begin
       if isURI(AURI,FList[i].FPATH, Params) then
       begin
          exit(FList[i]);
       end;
    end;
  end;
  result:= nil;
end;

function THttpServerCommandRegister.isUri(const AURI, AMask: String; AParams: TStringList): boolean;
var
  x: Integer;
  M : TMatch;

begin
  result := TRegEx.IsMatch(AURI, AMask);

  M := TRegEx.Match(AURI, AMask);

  for x := 0 to M.Groups.Count-1 do
  begin
    AParams.Add(M.Groups[x].Value);
  end;

end;

procedure THttpServerCommandRegister.Register(const ATYPE, APATH: String;
  ACommand: TRESTCommandClass);
begin
  FList.Add(TRESTCommandREG.Create(ATYPE, APATH, ACommand));
end;

{ TRESTCommandREG }

constructor TRESTCommandREG.Create(ATYPE, APATH: String;
  ACommand: TRESTCommandClass);
begin
  FTYPE:= AType;
  FPATH:= APATH;
  FCommand:= ACommand;
end;

{ TRESTCommand }

constructor TRESTCommand.create(AServer: THttpServerCommand);
begin
  FParams:= TStringList.Create;
end;

procedure TRESTCommand.start(AReg: TRESTCommandREG; AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; AParams: TStringList);
begin
  FContext:= AContext;
  FRequestInfo:= ARequestInfo;
  FResponseInfo:= AResponseInfo;
  FReg:= AReg;
  FParams.Assign(AParams);
  ParseParams(ARequestInfo.URI, AReg.FPATH);
  ReadStream(FRequestInfo);
end;

procedure TRESTCommand.ReadStream(ARequestInfo: TIdHTTPRequestInfo);
var
  oStream : TStringStream;

begin
  // Decode stream
  if ArequestInfo.PostStream <> nil then
  begin
    oStream := TStringStream.create;
    try
    oStream.CopyFrom(ArequestInfo.PostStream, ArequestInfo.PostStream.Size);
    oStream.Position := 0;

    FStreamContents := oStream.readString(oStream.Size);
    finally
      oStream.free;
    end;
  end;
end;

destructor TRESTCommand.Destroy;
begin
  FParams.free;
  inherited;
end;

procedure TRESTCommand.execute;
begin

end;

procedure TRESTCommand.ParseParams(const AURI, AMask: String);
var
  x: Integer;
  M : TMatch;

begin
  M := TRegEx.Match(AURI, AMask);

  for x := 0 to M.Groups.Count-1 do
  begin
    FParams.Add(M.Groups[x].Value);
  end;
end;

procedure TRESTCommand.ResponseJSON(Json: String);
begin
  ResponseInfo.ContentText := Json;
  ResponseInfo.ContentType := 'Application/JSON';
end;

procedure TRESTCommand.Error(code: integer);
begin
  ResponseInfo.ResponseNo := code;
end;

end.
