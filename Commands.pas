unit Commands;

interface

uses
  HttpServerCommand;

type
  TRestTestUnimplemented = class(TRestCommand)
  protected
    procedure execute; override;
  end;

  TRestTeste=class(TRESTCommand)
  protected
    procedure execute; override;
  end;

  TRestTeste2=class(TRESTCommand)
  protected
    procedure execute; override;
  end;

  TRestTesteParam=class(TRESTCommand)
  protected
    procedure execute; override;
  end;

implementation

uses
  System.SysUtils;

{ TRestTeste }

procedure TRestTeste.execute;
begin
  inherited;
  ResponseJSON('{''teste'':''ok''}');
end;

{ TRestTeste2 }

procedure TRestTeste2.execute;
begin
  inherited;
  ResponseJSON('{''teste2'':''ok''}');
end;

{ TRestTesteParam }

procedure TRestTesteParam.execute;
begin
  inherited;
  ResponseJSON('{''params'':'+QuotedStr(params.commatext)+'}');
end;

procedure TRestTestUnimplemented.execute;
begin
  Error(501);
end;

end.
