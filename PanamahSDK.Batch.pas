{$M+}
unit PanamahSDK.Batch;

interface

uses
  Classes, SysUtils, DateUtils, MD5, Windows, PanamahSDK.JsonUtils, uLkJSON, PanamahSDK.Types, PanamahSDK.Models.Acesso,
  PanamahSDK.Models.Assinante, PanamahSDK.Models.Cliente, PanamahSDK.Models.Compra, PanamahSDK.Models.Ean,
  PanamahSDK.Models.EstoqueMovimentacao, PanamahSDK.Models.EventoCaixa, PanamahSDK.Models.FormaPagamento,
  PanamahSDK.Models.Fornecedor, PanamahSDK.Models.Funcionario, PanamahSDK.Models.Grupo, PanamahSDK.Models.Holding,
  PanamahSDK.Models.LocalEstoque, PanamahSDK.Models.Loja, PanamahSDK.Models.Meta, PanamahSDK.Models.Produto,
  PanamahSDK.Models.Revenda, PanamahSDK.Models.Secao, PanamahSDK.Models.Subgrupo, PanamahSDK.Models.TituloPagar,
  PanamahSDK.Models.TituloReceber, PanamahSDK.Models.TrocaDevolucao, PanamahSDK.Models.TrocaFormaPagamento,
  PanamahSDK.Models.Venda, PanamahSDK.Operation;

type

  TPanamahBatchFilenameRec = record
  public
    CreatedAt: TDateTime;
    Priority: Boolean;
    class function Create(const AFilename: string): TPanamahBatchFilenameRec; static;
    class operator Implicit(AFilenameRec: TPanamahBatchFilenameRec): string;
    class operator Implicit(const AFilename: string): TPanamahBatchFilenameRec;
  end;

  IPanamahBatch = interface(IJSONSerializable)
    ['{97748D13-F5B3-48B8-AA21-19E769790589}']
    procedure SetCreatedAt(ACreatedAt: TDateTime);
    procedure SetPriority(APriority: Boolean);
    procedure SaveToFile(const AFilename: string);
    procedure Clear;
    procedure Reset;
    procedure Add(AOperation: IPanamahOperation); overload;
    function GetSize: Integer;
    function GetCreatedAt: TDateTime;
    function GetPriority: Boolean;
    function Clone: IPanamahBatch;
    function SaveToDirectory(const ADirectory: string): string;
    function MoveToDirectory(const ASource, ADestiny: string): string;
    function GetCount: Integer;
    function GetHash: string;
    function GetItem(AIndex: Integer): IPanamahOperation;
    property CreatedAt: TDateTime read GetCreatedAt write SetCreatedAt;
    property Size: Integer read GetSize;
    property Priority: Boolean read GetPriority write SetPriority;
    property Count: Integer read GetCount;
    property Hash: string read GetHash;
    property Items[AIndex: Integer]: IPanamahOperation read GetItem;
  end;

  IPanamahBatchList = interface(IJSONSerializable)
    ['{EDEDDB56-66F5-4501-8798-8DD44B3297D5}']
    function GetItem(AIndex: Integer): IPanamahBatch;
    procedure SetItem(AIndex: Integer; const Value: IPanamahBatch);
    procedure Add(const AItem: IPanamahBatch);
    procedure Clear;
    function Count: Integer;
    property Items[AIndex: Integer]: IPanamahBatch read GetItem write SetItem; default;
  end;

  TPanamahBatch = class(TInterfacedObject, IPanamahBatch)
  private
    FOperationList: IPanamahOperationList;
    FCreatedAt: TDateTime;
    FPriority: Boolean;
    procedure SetCreatedAt(ACreatedAt: TDateTime);
    procedure SetPriority(APriority: Boolean);
    procedure SaveToFile(const AFilename: string);
    procedure Clear;
    procedure Reset;
    function GetSize: Integer;
    function GetCreatedAt: TDateTime;
    function GetPriority: Boolean;
    function Clone: IPanamahBatch;
    function GetItem(AIndex: Integer): IPanamahOperation;
  public
    procedure DeserializeFromJSON(const AJSON: string);
    function SerializeToJSON: string;
    function SaveToDirectory(const ADirectory: string): string;
    function MoveToDirectory(const ASource, ADestiny: string): string;
    function GetCount: Integer;
    function GetHash: string;
    class function FromJSON(const AJSON: string): IPanamahBatch;
    class function FromFile(const AFilename: string): IPanamahBatch;
    property Items[AIndex: Integer]: IPanamahOperation read GetItem;
    procedure Add(AOperation: IPanamahOperation); overload;
  published
    property CreatedAt: TDateTime read GetCreatedAt write SetCreatedAt;
    property Size: Integer read GetSize;
    property Priority: Boolean read GetPriority write SetPriority;
    constructor Create; reintroduce;
  end;

  TBatchFileIterationProcedure = procedure(const ABatchFilename: string);

  TPanamahBatchList = class(TInterfacedObject, IPanamahBatchList)
  private
    FList: TInterfaceList;
    function GetItem(AIndex: Integer): IPanamahBatch;
    procedure SetItem(AIndex: Integer; const Value: IPanamahBatch);
    procedure AddJSONObjectToList(ElName: string; Elem: TlkJSONbase; Data: pointer; var Continue: Boolean);
    class function GetBatchesInDirectory(const ADirectory: string): TStrings;
  public
    function SerializeToJSON: string;
    procedure DeserializeFromJSON(const AJSON: string);
    class function FromJSON(const AJSON: string): IPanamahBatchList;
    class function FromDirectory(const ADirectory: string): IPanamahBatchList;
    class function CountBatchesInDirectory(const ADirectory: string): Integer;
    constructor Create;
    procedure Add(const AItem: IPanamahBatch);
    procedure Clear;
    function Count: Integer;
    destructor Destroy; override;
    property Items[AIndex: Integer]: IPanamahBatch read GetItem write SetItem; default;
  end;

implementation

{ TPanamahBatch }

procedure TPanamahBatch.Clear;
begin
  FOperationList.Clear;
end;

function TPanamahBatch.Clone: IPanamahBatch;
begin
  Result := TPanamahBatch.Create;
  Result.DeserializeFromJSON(SerializeToJSON);
end;

constructor TPanamahBatch.Create;
begin
  inherited;
  FCreatedAt := Now;
  FOperationList := TPanamahOperationList.Create;
end;

procedure TPanamahBatch.DeserializeFromJSON(const AJSON: string);
begin
  FOperationList.DeserializeFromJSON(AJSON);
end;

function TPanamahBatch.SaveToDirectory(const ADirectory: string): string;
var
  BatchFilename: TPanamahBatchFilenameRec;
begin
  BatchFilename.CreatedAt := FCreatedAt;
  BatchFilename.Priority := FPriority;
  ForceDirectories(ADirectory);
  SaveToFile(Format('%s/%s.pbt', [ADirectory, string(BatchFilename)]));
end;

procedure TPanamahBatch.SaveToFile(const AFilename: string);
var
  BatchFile : TextFile;
begin
  AssignFile(BatchFile, AFilename);
  try
    Rewrite(BatchFile);
    WriteLn(BatchFile, SerializeToJSON);
  finally
    CloseFile(BatchFile);
  end;
end;

function TPanamahBatch.SerializeToJSON: string;
begin
  Result := FOperationList.SerializeToJSON;
end;

procedure TPanamahBatch.SetCreatedAt(ACreatedAt: TDateTime);
begin
  FCreatedAt := ACreatedAt;
end;

procedure TPanamahBatch.SetPriority(APriority: Boolean);
begin
  FPriority := APriority;
end;

class function TPanamahBatch.FromFile(const AFilename: string): IPanamahBatch;
var
  BatchFilename: TPanamahBatchFilenameRec;
  BatchFile: TStrings;
begin
  Result := TPanamahBatch.Create;
  BatchFilename := AFilename;
  Result.CreatedAt := BatchFilename.CreatedAt;
  Result.Priority := BatchFilename.Priority;
  BatchFile := TStringList.Create;
  try
    BatchFile.LoadFromFile(AFilename);
    Result.DeserializeFromJSON(BatchFile.Text);
  finally
    BatchFile.Free;
  end;
end;

class function TPanamahBatch.FromJSON(const AJSON: string): IPanamahBatch;
begin
  Result := TPanamahBatch.Create;
  Result.DeserializeFromJSON(AJSON);
end;

function TPanamahBatch.GetCount: Integer;
begin
  Result := FOperationList.Count;
end;

function TPanamahBatch.GetCreatedAt: TDateTime;
begin
  Result := FCreatedAt;
end;

function TPanamahBatch.GetHash: string;
begin
  Result := MD5DigestToStr(MD5String(SerializeToJSON));
end;

function TPanamahBatch.GetItem(AIndex: Integer): IPanamahOperation;
begin
  Result := FOperationList[AIndex];
end;

function TPanamahBatch.GetPriority: Boolean;
begin
  Result := FPriority;
end;

function TPanamahBatch.GetSize: Integer;
begin
  Result := Length(SerializeToJSON);
end;

function TPanamahBatch.MoveToDirectory(const ASource, ADestiny: string): string;
var
  BatchFilename: TPanamahBatchFilenameRec;
  SourceFile, DestinyFile: string;
begin
  BatchFilename.CreatedAt := FCreatedAt;
  BatchFilename.Priority := FPriority;
  ForceDirectories(ADestiny);
  SourceFile := Format('%s\%s.pbt', [ASource, string(BatchFilename)]);
  DestinyFile := Format('%s\%s.pbt', [ADestiny, string(BatchFilename)]);
  MoveFile(PChar(SourceFile), PChar(DestinyFile));
  Result := DestinyFile;
end;

procedure TPanamahBatch.Reset;
begin
  Clear;
  FCreatedAt := Now;
  FPriority := False;
end;

procedure TPanamahBatch.Add(AOperation: IPanamahOperation);
begin
  FOperationList.Add(AOperation);
end;

{ TPanamahBatchList }

constructor TPanamahBatchList.Create;
begin
  FList := TInterfaceList.Create;
end;

destructor TPanamahBatchList.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

class function TPanamahBatchList.FromDirectory(const ADirectory: string): IPanamahBatchList;
var
  Batches: TStrings;
  I: Integer;
begin
  Result := TPanamahBatchList.Create;
  Batches := GetBatchesInDirectory(ADirectory);
  try
    for I := 0 to Batches.Count - 1 do
      Result.Add(TPanamahBatch.FromFile(Batches[I]));
  finally
    Batches.Free;
  end;
end;

class function TPanamahBatchList.FromJSON(const AJSON: string): IPanamahBatchList;
begin
  Result := TPanamahBatchList.Create;
  Result.DeserializeFromJSON(AJSON);
end;

procedure TPanamahBatchList.Add(const AItem: IPanamahBatch);
begin
  FList.Add(AItem);
end;

procedure TPanamahBatchList.AddJSONObjectToList(ElName: string; Elem: TlkJSONbase; Data: pointer;
  var Continue: Boolean);
var
  Item: IPanamahBatch;
begin
  Item := TPanamahBatch.Create;
  Item.DeserializeFromJSON(TlkJSON.GenerateText(Elem));
  FList.Add(Item);
end;

procedure TPanamahBatchList.Clear;
begin
  FList.Clear;
end;

function TPanamahBatchList.Count: Integer;
begin
  Result := FList.Count;
end;

class function TPanamahBatchList.CountBatchesInDirectory(const ADirectory: string): Integer;
var
  Batches: TStrings;
begin
  Batches := GetBatchesInDirectory(ADirectory);
  try
    Result := Batches.Count;
  finally
    Batches.Free;
  end;
end;

function TPanamahBatchList.GetItem(AIndex: Integer): IPanamahBatch;
begin
  Result := FList.Items[AIndex] as IPanamahBatch;
end;

class function TPanamahBatchList.GetBatchesInDirectory(const ADirectory: string): TStrings;
var
  SearchRec: TSearchRec;
begin
  ForceDirectories(ADirectory);
  Result := TStringList.Create;
  if DirectoryExists(ADirectory) then
    begin
    if FindFirst(Format('%s\*.pbt', [ADirectory]), faAnyFile, SearchRec) = 0 then
    begin
      repeat
        Result.Add(Format('%s\%s', [ADirectory, SearchRec.Name]));
      until FindNext(SearchRec) <> 0;
    end;
  end
  else
    raise PanamahSDKIOException.Create(Format('Diret�rio %s n�o existe.', [ADirectory]));
end;

procedure TPanamahBatchList.SetItem(AIndex: Integer;
  const Value: IPanamahBatch);
begin
  FList[AIndex] := Value;
end;

procedure TPanamahBatchList.DeserializeFromJSON(const AJSON: string);
begin
  with TlkJSON.ParseText(AJSON) as TlkJSONlist do
  begin
    ForEach(AddJSONObjectToList, nil);
    Free;
  end;
end;

function TPanamahBatchList.SerializeToJSON: string;
var
  JSONObject: TlkJSONlist;
  I: Integer;
begin
  JSONObject := TlkJSONlist.Create;
  try
    for I := 0 to FList.Count - 1 do
      JSONObject.Add(TlkJSON.ParseText((FList[I] as IPanamahBatch).SerializeToJSON));
    Result := TlkJSON.GenerateText(JSONObject);
  finally
    JSONObject.Free;
  end;
end;

{ TPanamahBatchFilenameRec }

class function TPanamahBatchFilenameRec.Create(const AFilename: string): TPanamahBatchFilenameRec;
var
  Words: TStrings;
begin
  FillChar(Result, SizeOf(TPanamahBatchFilenameRec), 0);
  Words := TStringList.Create;
  try
    Words.Delimiter := '_';
    Words.DelimitedText := ChangeFileExt(ExtractFilename(AFilename), EmptyStr);
    if Words.Count >= 7 then
    begin
      Result.CreatedAt := ISO8601ToDateTime(Format('%s-%s-%sT%s:%s:%s.%s', [
        Words[0],
        Words[1],
        Words[2],
        Words[3],
        Words[4],
        Words[5],
        Words[6]
      ]));
    end;
    if Words.Count >= 8 then
      Result.Priority := SameText(Words[7], 'P');
  finally
    Words.Free;
  end;
end;

class operator TPanamahBatchFilenameRec.Implicit(AFilenameRec: TPanamahBatchFilenameRec): string;
begin
  Result := FormatDateTime('YYYY_MM_DD_HH_NN_SS_ZZZ', AFilenameRec.CreatedAt);
  if AFilenameRec.Priority then
    Result := Concat(Result, '_P');
end;

class operator TPanamahBatchFilenameRec.Implicit(const AFilename: string): TPanamahBatchFilenameRec;
begin
  Result := TPanamahBatchFilenameRec.Create(AFilename);
end;

end.