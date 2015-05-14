unit WinMsgCommPeer;

interface

{$INCLUDE '.\WinMsgComm_defs.inc'}

uses
  Windows, UtilityWindow, WinMsgComm;

type
  TOnPeerEvent = procedure(Sender: TObject; PeerInfo: TWMCConnectionInfo; ConnectionIndex: Integer) of object;

  TWinMsgCommPeer = class(TWinMsgCommBase)
  private
    fOnPeerConnect:     TOnPeerEvent;
    fOnPeerDisconnect:  TOnPeerEvent;
  protected
    Function ProcessMessage(SenderID: TWMCConnectionID; MessageCode, UserCode: Byte; Payload: lParam): lResult; override;
  public
    constructor Create; overload;
    constructor Create(Window: TUtilityWindow; Synchronous: Boolean; const MessageRegName: String); overload;
    destructor Destroy; override;
    Function SendMessage(MessageCode, UserCode: Byte; Payload: lParam; RecipientID: TWMCConnectionID = WMC_SendToAll): lResult; override;
  published
    property OnPeerConnect: TOnPeerEvent read fOnPeerConnect write fOnPeerConnect;
    property OnPeerDisconnect: TOnPeerEvent read fOnPeerDisconnect write fOnPeerDisconnect;
  end;

implementation

//******************************************************************************

Function TWinMsgCommPeer.ProcessMessage(SenderID: TWMCConnectionID; MessageCode, UserCode: Byte; Payload: lParam): lResult;
var
  NewPeer:  PWMCConnectionInfo;
  Index:    Integer;
begin
case MessageCode of
  WMC_QUERYSERVER:    Result := WMC_RESULT_error;
  WMC_SERVERONLINE:   Result := WMC_RESULT_error;
  WMC_SERVEROFFLINE:  Result := WMC_RESULT_error;
  WMC_CLIENTONLINE:   Result := WMC_RESULT_error;
  WMC_CLIENTOFFLINE:  Result := WMC_RESULT_error;
  WMC_ISSERVER:       Result := WMC_RESULT_error;
  WMC_QUERYPEERS:     begin
                        If HWND(Payload) <> WindowHandle then
                          begin
                            SendMessageTo(HWND(Payload),BuildWParam(ID,WMC_PEERONLINE,0),lParam(WindowHandle),True);
                            Result := WMC_RESULT_ok;
                          end
                        else Result := WMC_RESULT_error;
                      end;
  WMC_PEERONLINE:     begin
                        New(NewPeer);
                        NewPeer^.ConnectionID := SenderID;
                        NewPeer^.WindowHandle := HWND(Payload);
                        NewPeer^.Transacting := False;
                        Index := AddConnection(NewPeer);
                        Result := WMC_RESULT_ok;
                        If Assigned(fOnPeerConnect) then fOnPeerConnect(Self,NewPeer^,Index);
                      end;
  WMC_PEEROFFLINE:    begin
                        Index := IndexOfConnection(SenderID);
                        If Index >= 0 then
                          begin
                            If Assigned(fOnPeerDisconnect) then fOnPeerDisconnect(Self,Connections[Index],Index);
                            DeleteConnection(Index);
                            Result := WMC_RESULT_ok;
                          end
                        else Result := WMC_RESULT_error;
                      end;
else
  Result := inherited ProcessMessage(SenderID,MessageCode,UserCode,Payload);
end;
end;

//==============================================================================

constructor TWinMsgCommPeer.Create;
begin
Create(nil,False,WMC_MessageName);
end;

//------------------------------------------------------------------------------

constructor TWinMsgCommPeer.Create(Window: TUtilityWindow; Synchronous: Boolean; const MessageRegName: String);
begin
inherited Create(Window,Synchronous,MessageRegName);
SendMessageTo(HWND_BROADCAST,BuildWParam(ID,WMC_QUERYPEERS,0),lParam(WindowHandle),True);
SetID(GetFreeID);
SendMessageToAll(BuildWParam(ID,WMC_PEERONLINE,0),lParam(WindowHandle),False);
end;

//------------------------------------------------------------------------------

destructor TWinMsgCommPeer.Destroy;
begin
SendMessageTo(HWND_BROADCAST,BuildWParam(ID,WMC_PEEROFFLINE,0),lParam(WindowHandle),False);
inherited;
end;

//------------------------------------------------------------------------------

Function TWinMsgCommPeer.SendMessage(MessageCode, UserCode: Byte; Payload: lParam; RecipientID: TWMCConnectionID = WMC_SendToAll): lResult;
var
  Index:  Integer;
begin
If RecipientID = 0 then
  Result := SendMessageToAll(BuildWParam(ID,MessageCode,UserCode),Payload)
else
  begin
    Index := IndexOfConnection(RecipientID);
    If Index >= 0 then
      Result := SendMessageTo(Connections[Index].WindowHandle,BuildWParam(ID,MessageCode,UserCode),Payload)
    else
      Result := WMC_RESULT_error;
  end;
end;

end.