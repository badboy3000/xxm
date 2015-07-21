unit xxmReadHandler;

interface

uses Classes, blcksock, xxm, ActiveX;

type
  THandlerReadStreamAdapter=class(TStream)
  private
    FSize:Int64;
    FSocket:TTCPBlockSocket;
    FStore:TStream;
    FStorePosition,FPosition:int64;
  protected
    function GetSize: Int64; override;
    procedure SetSize(NewSize: Longint); overload; override;
    procedure SetSize(const NewSize: Int64); overload; override;
  public
    constructor Create(Socket:TTCPBlockSocket;Size:Int64;StoreStream:TStream;
      const StartData:AnsiString);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
  end;

  TRawSocketData=class(TInterfacedObject, IStream, IXxmRawSocket)
  private
    FSocket:TTCPBlockSocket;
  public
    constructor Create(Socket:TTCPBlockSocket);
    destructor Destroy; override;
    { IStream }
    function Seek(dlibMove: Largeint; dwOrigin: Longint;
      out libNewPosition: Largeint): HResult; stdcall;
    function SetSize(libNewSize: Largeint): HResult; stdcall;
    function CopyTo(stm: IStream; cb: Largeint; out cbRead: Largeint;
      out cbWritten: Largeint): HResult; stdcall;
    function Commit(grfCommitFlags: Longint): HResult; stdcall;
    function Revert: HResult; stdcall;
    function LockRegion(libOffset: Largeint; cb: Largeint;
      dwLockType: Longint): HResult; stdcall;
    function UnlockRegion(libOffset: Largeint; cb: Largeint;
      dwLockType: Longint): HResult; stdcall;
    function Stat(out statstg: TStatStg; grfStatFlag: Longint): HResult;
      stdcall;
    function Clone(out stm: IStream): HResult; stdcall;
    { ISequentialStream }
    function Read(pv: Pointer; cb: Longint; pcbRead: PLongint): HResult;
      stdcall;
    function Write(pv: Pointer; cb: Longint; pcbWritten: PLongint): HResult;
      stdcall;
    { IXxmRawSocket }
    function DataReady(TimeoutMS: cardinal): boolean;
    procedure Disconnect;
  end;

implementation

uses SysUtils;

{ THandlerReadStreamAdapter }

constructor THandlerReadStreamAdapter.Create(Socket: TTCPBlockSocket;
  Size: Int64; StoreStream: TStream; const StartData: AnsiString);
var
  l:integer;
begin
  inherited Create;
  FSize:=Size;
  FSocket:=Socket;
  FStore:=StoreStream;
  //FStore.Size:=FSize;//done by caller? (don't care really)
  //assert FStore.Position:=0;
  l:=Length(StartData);
  if l<>0 then FStore.Write(StartData[1],l);
  FStorePosition:=l;
  FPosition:=0;
end;

function THandlerReadStreamAdapter.GetSize: Int64;
begin
  Result:=FSize;//from HTTP request header
end;

function THandlerReadStreamAdapter.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:Result:=Offset;
    soCurrent:Result:=FPosition+Offset;
    soEnd:Result:=FSize+Offset;
    else Result:=FPosition+Offset;//raise?
  end;
  if (Result<0) or (Result>FSize) then
    raise Exception.Create('THandlerReadStreamAdapter.Seek past end not allowed');
  if (Result>FStorePosition) then
    raise Exception.Create('THandlerReadStreamAdapter.Seek past current incoming position not allowed');//TODO: force read?
  FStore.Position:=Result;
  FPosition:=Result;
end;

function THandlerReadStreamAdapter.Read(var Buffer; Count: Integer): Longint;
var
  x:AnsiString;
begin
  if FPosition=FStorePosition then
   begin
    if FPosition+Count>FSize then
      Result:=FSize-FPosition
    else
      Result:=Count;
    if Result<>0 then
     begin
      //Result:=FSocket.RecvBuffer(@Buffer,Result);
      //FStore.Write(Buffer,Result);
      x:=FSocket.RecvPacket(1000);
      Result:=Length(x);
      FStore.Write(x[1],Result);
      inc(FPosition,Result);
      inc(FStorePosition,Result);
     end;
   end
  else
    if FPosition<FStorePosition then
     begin
      if FPosition+Count>FStorePosition then
        Result:=FStorePosition-FPosition
      else
        Result:=Count;
      FStore.Position:=FPosition;
      Result:=FStore.Read(Buffer,Result);
      inc(FPosition,Result);
      FStore.Position:=FStorePosition;
      //TODO: read FPosition+Count-FStorePosition
     end
    else
      raise Exception.Create('THandlerReadStreamAdapter.Read past current incoming position not allowed');//TODO: force read?
end;

procedure THandlerReadStreamAdapter.SetSize(NewSize: Integer);
begin
  raise Exception.Create('THandlerReadStreamAdapter.SetSize not supported');
end;

procedure THandlerReadStreamAdapter.SetSize(const NewSize: Int64);
begin
  raise Exception.Create('THandlerReadStreamAdapter.SetSize not supported');
end;

function THandlerReadStreamAdapter.Write(const Buffer;
  Count: Integer): Longint;
begin
  raise Exception.Create('THandlerReadStreamAdapter.Write not supported');
end;

destructor THandlerReadStreamAdapter.Destroy;
begin
  FStore.Free;
  inherited;
end;

{ TRawSocketData }

constructor TRawSocketData.Create(Socket:TTCPBlockSocket);
begin
  inherited Create;
  FSocket:=Socket;
end;

destructor TRawSocketData.Destroy;
begin
  FSocket:=nil;
  inherited;
end;

function TRawSocketData.Clone(out stm: IStream): HResult;
begin
  raise Exception.Create('TRawSocketData.Clone not supported');
end;

function TRawSocketData.Commit(grfCommitFlags: Integer): HResult;
begin
  raise Exception.Create('TRawSocketData.Commit not supported');
end;

function TRawSocketData.CopyTo(stm: IStream; cb: Largeint; out cbRead,
  cbWritten: Largeint): HResult;
begin
  raise Exception.Create('TRawSocketData.CopyTo not supported');
end;

function TRawSocketData.LockRegion(libOffset, cb: Largeint;
  dwLockType: Integer): HResult;
begin
  raise Exception.Create('TRawSocketData.LockRegion not supported');
end;

function TRawSocketData.Revert: HResult;
begin
  raise Exception.Create('TRawSocketData.Revert not supported');
end;

function TRawSocketData.Seek(dlibMove: Largeint; dwOrigin: Integer;
  out libNewPosition: Largeint): HResult;
begin
  raise Exception.Create('TRawSocketData.Seek not supported');
end;

function TRawSocketData.SetSize(libNewSize: Largeint): HResult;
begin
  raise Exception.Create('TRawSocketData.SetSize not supported');
end;

function TRawSocketData.Stat(out statstg: TStatStg;
  grfStatFlag: Integer): HResult;
begin
  raise Exception.Create('TRawSocketData.Stat not supported');
end;

function TRawSocketData.UnlockRegion(libOffset, cb: Largeint;
  dwLockType: Integer): HResult;
begin
  raise Exception.Create('TRawSocketData.UnlockRegion not supported');
end;

function TRawSocketData.Read(pv: Pointer; cb: Integer;
  pcbRead: PLongint): HResult;
var
  l:integer;
begin
  l:=FSocket.RecvBuffer(pv,cb);
  if pcbRead<>nil then pcbRead^:=l;
  Result:=S_OK;
end;

function TRawSocketData.Write(pv: Pointer; cb: Integer;
  pcbWritten: PLongint): HResult;
var
  l:integer;
begin
  l:=FSocket.SendBuffer(pv,cb);
  if pcbWritten<>nil then pcbWritten^:=l;
  Result:=S_OK;
end;

function TRawSocketData.DataReady(TimeoutMS: cardinal): boolean;
begin
  Result:=FSocket.CanRead(TimeoutMS)
end;

procedure TRawSocketData.Disconnect;
begin
  FSocket.CloseSocket;
end;

end.
