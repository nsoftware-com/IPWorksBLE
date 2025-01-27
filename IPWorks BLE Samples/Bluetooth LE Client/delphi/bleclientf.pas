(*
 * IPWorks BLE 2024 Delphi Edition - Sample Project
 *
 * This sample project demonstrates the usage of IPWorks BLE in a 
 * simple, straightforward way. It is not intended to be a complete 
 * application. Error handling and other checks are simplified for clarity.
 *
 * www.nsoftware.com/ipworksble
 *
 * This code is subject to the terms and conditions specified in the 
 * corresponding product license agreement which outlines the authorized 
 * usage and restrictions.
 *)
unit bleclientf;

interface

uses
  Windows, Messages, SysUtils, Variants, Graphics,
  Forms, Dialogs, iplcore, ipltypes,
  iplbleclient, ComCtrls, Controls, StdCtrls, Classes;

type
  TFormBLEClient = class(TForm)
    iplBLEClient1: TiplBLEClient;
    pcMainApplicationWindow: TPageControl;
    tsScanConnect: TTabSheet;
    tsBrowseData: TTabSheet;
    lblDemoIntro: TLabel;
    gbScanning: TGroupBox;
    lvAdvertisements: TListView;
    gbConnection: TGroupBox;
    lblServerIdConnect: TLabel;
    tbServerIdConnect: TEdit;
    btConnect: TButton;
    btStartScanning: TButton;
    btDisconnect: TButton;
    lblCurrentlyConnectedTo: TLabel;
    tbCurrentlyConnectedTo: TEdit;
    cbUseActiveScanning: TCheckBox;
    lblGATTObjectsTree: TLabel;
    tvGATTObjectsTree: TTreeView;
    lblServerName: TLabel;
    tbServerName: TEdit;
    lblServerIdBrowseData: TLabel;
    tbServerIdBrowseData: TEdit;
    gbDiscoverEverything: TGroupBox;
    lblDiscoverEverythingWarning: TLabel;
    btDiscoverEverything: TButton;
    lblServiceName: TLabel;
    lblServiceUUID: TLabel;
    lblServiceId: TLabel;
    tbServiceUUID: TEdit;
    tbServiceName: TEdit;
    tbServiceId: TEdit;
    lblCharacteristicName: TLabel;
    lblCharacteristicUuid: TLabel;
    lblCharacteristicId: TLabel;
    lblFlags: TLabel;
    tbCharacteristicName: TEdit;
    tbCharacteristicUuid: TEdit;
    tbCharacteristicId: TEdit;
    tbFlags: TEdit;
    gbBrowseDataInfo: TGroupBox;
    gbServerInfo: TGroupBox;
    gbServiceInfo: TGroupBox;
    gbCharacteristicInfo: TGroupBox;
    gbDescriptorInfo: TGroupBox;
    lblDescriptorName: TLabel;
    lblDescriptorUUID: TLabel;
    lblDescriptorId: TLabel;
    tbDescriptorName: TEdit;
    tbDescriptorUuid: TEdit;
    tbDescriptorId: TEdit;
    btnSubscribe: TButton;
    btnReadValue: TButton;
    tbCharacteristicValue: TEdit;
    procedure btStartScanningClick(Sender: TObject);
    procedure iplBLEClient1Advertisement(Sender: TObject; const ServerId,
      Name: string; RSSI, TxPower: Integer; const ServiceUuids,
      ServicesWithData, SolicitedServiceUuids: string;
      ManufacturerCompanyId: Integer; ManufacturerData: string; ManufacturerDataB: TBytes; IsConnectable,
      IsScanResponse: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure lvAdvertisementsSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure btConnectClick(Sender: TObject);
    procedure btDisconnectClick(Sender: TObject);
    procedure iplBLEClient1Connected(Sender: TObject; StatusCode: Integer;
      const Description: string);
    procedure iplBLEClient1Disconnected(Sender: TObject; StatusCode: Integer;
      const Description: string);
    procedure btDiscoverEverythingClick(Sender: TObject);
    procedure iplBLEClient1Discovered(Sender: TObject; GattType: Integer;
      const ServiceId, CharacteristicId, DescriptorId, Uuid,
      Description: string);
    procedure FormDestroy(Sender: TObject);
    function GetNodeIndex(Id: String) : Integer;
    function GetServiceIndex(Id: String) : Integer;
    function GetCharacteristicIndex(Id: String) : Integer;
    function GetDescriptorIndex(Id: String) : Integer;
    procedure TranslateFlags(Flags: Integer);
    function HasFlag(Flags, Flag: Integer) : Boolean;
    procedure tvGATTObjectsTreeClick(Sender: TObject);
    procedure tvGATTObjectsTreeAddition(Sender: TObject; Node: TTreeNode);
    procedure btnReadValueClick(Sender: TObject);
    procedure iplBLEClient1Value(Sender: TObject; const ServiceId,
      CharacteristicId, DescriptorId, Uuid, Description: string; Value: string; ValueB: TBytes);
    procedure btnSubscribeClick(Sender: TObject);
    procedure iplBLEClient1Subscribed(Sender: TObject; const ServiceId,
      CharacteristicId, Uuid, Description: string);  
    function TBytesToHex(data: TBytes) : string;
  private
    { Private declarations }
    isScanning: Boolean;
    ServerIds: TStringList;
    ServiceIds: TStringList;
    FlagsList: TStringList;
  public
    { Public declarations }
  end;

var
  FormBLEClient: TFormBLEClient;

const
  CHAR_FLAG_BROADCAST         = $00000001;
  CHAR_FLAG_READ              = $00000002;
  CHAR_FLAG_WRITE_NO_RESPONSE = $00000004;
  CHAR_FLAG_WRITE             = $00000008;
  CHAR_FLAG_NOTIFY            = $00000010;
  CHAR_FLAG_INDICATE          = $00000020;
  CHAR_FLAG_AUTH_SIGNED_WRITE = $00000040;
  CHAR_FLAG_RELIABLE_WRITE    = $00000080;
  CHAR_FLAG_WRITEABLE_AUX     = $00000100;

implementation

{$R *.dfm}

function TFormBLEClient.HasFlag(Flags: Integer; Flag: Integer) : Boolean;
begin
  Result := (Flags AND flag) = flag;
end;

procedure TFormBLEClient.TranslateFlags(Flags: Integer);
begin
  FlagsList.Clear;
  if HasFlag(Flags, CHAR_FLAG_BROADCAST) then
    FlagsList.Add('Broadcast');
  if HasFlag(Flags, CHAR_FLAG_READ) then
    FlagsList.Add('Read');
  if HasFlag(Flags, CHAR_FLAG_WRITE_NO_RESPONSE) then
    FlagsList.Add('Write Without Response');
   if HasFlag(Flags, CHAR_FLAG_WRITE) then
    FlagsList.Add('Write');
   if HasFlag(Flags, CHAR_FLAG_NOTIFY) then
    FlagsList.Add('Notify');
   if HasFlag(Flags, CHAR_FLAG_INDICATE) then
    FlagsList.Add('Indicate');
   if HasFlag(Flags, CHAR_FLAG_AUTH_SIGNED_WRITE) then
    FlagsList.Add('Authenticated Signed Writes');
   if HasFlag(Flags, CHAR_FLAG_RELIABLE_WRITE) then
    FlagsList.Add('Reliable Writes (extended property)');
   if HasFlag(Flags, CHAR_FLAG_WRITEABLE_AUX) then
    FlagsList.Add('Writable Auxiliaries (extended property)');
end;

function TFormBLEClient.GetDescriptorIndex(Id: string) : Integer;
var
  I: Integer;
  DescriptorIndex: Integer;
begin
  DescriptorIndex := -1;
  iplBLEClient1.Service := tvGATTObjectsTree.Selected.Parent.Parent.Text;
  iplBLEClient1.Characteristic := tvGATTObjectsTree.Selected.Parent.Text;
  for I := 0 to iplBLEClient1.DescriptorCount-1 do
  begin
    if iplBLEClient1.DescriptorId[I] = Id then
    begin
      DescriptorIndex := I;
      break;
    end;
  end;
  Result := DescriptorIndex;
end;

function TFormBLEClient.GetCharacteristicIndex(Id: string) : Integer;
var
  I: Integer;
  CharacteristicIndex: Integer;
begin
  CharacteristicIndex := -1;
  if tvGATTObjectsTree.Selected.Level = 2 then
  begin
    iplBLEClient1.Service := tvGATTObjectsTree.Selected.Parent.Text;
  end
  else
  begin
    iplBLEClient1.Service := tvGATTObjectsTree.Selected.Parent.Parent.Text;
  end;
  for I := 0 to iplBLEClient1.CharacteristicCount-1 do
  begin
    if iplBLEClient1.CharacteristicId[I] = Id then
    begin
      CharacteristicIndex := I;
      break;
    end;
  end;
  Result := CharacteristicIndex;
end;

function TFormBLEClient.GetServiceIndex(Id: string) : Integer;
var
  I: Integer;
  ServiceIndex: Integer;
begin
  ServiceIndex := -1;
  for I := 0 to iplBLEClient1.ServiceCount-1 do
  begin
    if iplBLEClient1.ServiceId[I] = Id then
    begin
      ServiceIndex := I;
      break;
    end;
  end;
  Result := ServiceIndex;
end;

function TFormBLEClient.GetNodeIndex(Id: string) : Integer;
var
  I: Integer;
  NodeIndex: Integer;
begin
  NodeIndex := -1;
  for I := 0 to tvGATTObjectsTree.Items.Count-1 do
  begin
    if tvGATTObjectsTree.Items[I].Text = Id then
    begin
      NodeIndex := I;
    end;
  end;
  Result := NodeIndex;
end;

procedure TFormBLEClient.btConnectClick(Sender: TObject);
begin
  iplBLEClient1.Connect(tbServerIdConnect.Text);
end;

procedure TFormBLEClient.btDisconnectClick(Sender: TObject);
begin
  iplBLEClient1.Disconnect();
end;

procedure TFormBLEClient.btDiscoverEverythingClick(Sender: TObject);
begin
  iplBLEClient1.Discover('', '', true, '');
end;

procedure TFormBLEClient.btnReadValueClick(Sender: TObject);
begin
  // Ensure a characteristic is selected
  if tvGATTObjectsTree.Selected.Level = 2 then
  begin
    iplBLEClient1.ReadValue(tvGATTObjectsTree.Selected.Parent.Text, tvGATTObjectsTree.Selected.Text, '');
  end
  else
  begin
    MessageDlg('Please select a characteristic', mtCustom, [mbOK], 0);
  end;
end;

procedure TFormBLEClient.btnSubscribeClick(Sender: TObject);
var
  Index: Integer;
begin
  // Ensure a characteristic is selected
  if tvGATTObjectsTree.Selected.Level = 2 then
  begin
    Index := GetCharacteristicIndex(tvGATTObjectsTree.Selected.Text);
    if iplBLEClient1.CheckCharacteristicSubscribed(Index) then
    begin
      iplBLEClient1.Unsubscribe(tvGATTObjectsTree.Selected.Parent.Text, tvGATTObjectsTree.Selected.Text);
      btnSubscribe.Caption := 'Subscribe';
    end
    else
    begin
      iplBLEClient1.Subscribe(tvGATTObjectsTree.Selected.Parent.Text, tvGATTObjectsTree.Selected.Text);
      btnSubscribe.Caption := 'Unsubscribe';
    end;
  end
  else
  begin
    MessageDlg('Please select a characteristic', mtCustom, [mbOK], 0);
  end;
end;

procedure TFormBLEClient.btStartScanningClick(Sender: TObject);
begin
  if isScanning then
  begin
    btStartScanning.Enabled := false;
    btStartScanning.Caption := 'Start Scanning';
    iplBLEClient1.StopScanning();
    isScanning := false;
    btStartScanning.Enabled := true;
  end
  else
  begin
    btStartScanning.Enabled := false;
    lvAdvertisements.Clear;
    ServerIds.Clear;
    btStartScanning.Caption := 'Stop Scanning';
    iplBLEClient1.ActiveScanning := cbUseActiveScanning.Checked;
    iplBLEClient1.StartScanning(''); // TBD add way to add filters
    isScanning := true;
    btStartScanning.Enabled := true;
  end;
end;

procedure TFormBLEClient.FormCreate(Sender: TObject);
begin
  pcMainApplicationWindow.ActivePageIndex := 0;
  FlagsList := TStringList.Create;
  ServerIds := TStringList.Create;
  ServiceIds := TStringList.Create;
  isScanning := false;
end;

procedure TFormBLEClient.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FlagsList);
  FreeAndNil(ServerIds);
  FreeAndNil(ServiceIds);
  iplBLEClient1.Disconnect();
end;

procedure TFormBLEClient.iplBLEClient1Advertisement(Sender: TObject; const ServerId,
  Name: string; RSSI, TxPower: Integer; const ServiceUuids, ServicesWithData,
  SolicitedServiceUuids: string; ManufacturerCompanyId: Integer;
  ManufacturerData: string; ManufacturerDataB: TBytes; IsConnectable, IsScanResponse: Boolean);
var
  serverIdExists: Boolean;
  I: Integer;
begin
  // This method will check to see if the ServerID already exists. If it does not,
  // then display advertisement information for it.

  serverIdExists := false;
  if ServerIds.Count = 0 then
  begin
    ServerIds.Add(ServerId);
  end
  else
  begin
    for I := 0 to ServerIds.Count-1 do
    begin
      if ServerIds[I] = ServerId then
      begin
        serverIdExists := true;
        break;
      end;
    end;
  end;

  if not serverIdExists then
  begin
    ServerIds.Add(ServerId);
    lvAdvertisements.Items.Add();
    lvAdvertisements.Items[lvAdvertisements.Items.Count-1].Caption := ServerId;
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(Name);
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(inttostr(RSSI));
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(inttostr(TxPower));
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(booltostr(IsConnectable, True));
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(ServiceUuids);
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(ServicesWithData);
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(inttostr(ManufacturerCompanyId));
    lvAdvertisements.Items.Item[lvAdvertisements.Items.Count-1].SubItems.Add(TBytesToHex(ManufacturerDataB)); // Needs to be converted to hex string
  end
end;

procedure TFormBLEClient.iplBLEClient1Connected(Sender: TObject; StatusCode: Integer;
  const Description: string);
begin
  tbCurrentlyConnectedTo.Text := iplBLEClient1.ServerId;
  tbServerIdBrowseData.Text := iplBLEClient1.ServerId;
  tbServerName.Text := iplBLEClient1.ServerName;
  tvGATTObjectsTree.Items.AddFirst(nil, iplBLEClient1.ServerName);
end;

procedure TFormBLEClient.iplBLEClient1Disconnected(Sender: TObject; StatusCode: Integer;
  const Description: string);
begin
  tbCurrentlyConnectedTo.Text := '[Not Connected]';
end;

procedure TFormBLEClient.iplBLEClient1Discovered(Sender: TObject; GattType: Integer;
  const ServiceId, CharacteristicId, DescriptorId, Uuid, Description: string);
begin
  if GattType = 0 then
  begin
    tvGATTObjectsTree.Items.AddChild(tvGATTObjectsTree.Items[0], ServiceId);
  end
  else if GattType = 1 then
  begin
    tvGATTObjectsTree.Items.AddChild(tvGATTObjectsTree.Items[GetNodeIndex(ServiceId)], CharacteristicId);
  end
  else if GattType = 2 then
  begin
    tvGATTObjectsTree.Items.AddChild(tvGATTObjectsTree.Items[GetNodeIndex(CharacteristicId)], DescriptorId);
  end;
end;

procedure TFormBLEClient.iplBLEClient1Subscribed(Sender: TObject; const ServiceId,
  CharacteristicId, Uuid, Description: string);
begin
  MessageDlg('Subscribed!', mtCustom, [mbOk], 0);
end;

procedure TFormBLEClient.iplBLEClient1Value(Sender: TObject; const ServiceId,
  CharacteristicId, DescriptorId, Uuid, Description: string; Value: string; ValueB: TBytes);
begin
  // Be aware that values can come back in many formats. Accordingly this string may appear garbled.
  tbCharacteristicValue.Text := TBytesToHex(ValueB);
end;

procedure TFormBLEClient.lvAdvertisementsSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  tbServerIdConnect.Text := Item.Caption;
end;

procedure TFormBLEClient.tvGATTObjectsTreeAddition(Sender: TObject; Node: TTreeNode);
begin
  tvGATTObjectsTree.Select(Node);
end;

procedure TFormBLEClient.tvGATTObjectsTreeClick(Sender: TObject);
var
  Index: Integer;
  Flags: String;
  I: Integer;
begin
  btnSubscribe.Caption := 'Subscribe';
  if tvGATTObjectsTree.Selected.Level = 1 then // Services
  begin

    tbCharacteristicName.Text := '';
    tbCharacteristicUuid.Text := '';
    tbCharacteristicId.Text := '';
    tbFlags.Text := '';

    tbDescriptorName.Text := '';
    tbDescriptorUuid.Text := '';
    tbDescriptorId.Text := '';
    Index := GetServiceIndex(tvGATTObjectsTree.Selected.Text);
    tbServiceName.Text := iplBLEClient1.ServiceDescription[Index];
    tbServiceUUID.Text := iplBLEClient1.ServiceUuid[Index];
    tbServiceId.Text := iplBLEClient1.ServiceId[Index];
    btnReadValue.Enabled := False;
    btnSubscribe.Enabled := False;
  end
  else if tvGATTObjectsTree.Selected.Level = 2 then // Characteristics
  begin

    tbDescriptorName.Text := '';
    tbDescriptorUuid.Text := '';
    tbDescriptorId.Text := '';
    Index := GetServiceIndex(tvGATTObjectsTree.Selected.Parent.Text);
    tbServiceName.Text := iplBLEClient1.ServiceDescription[Index];
    tbServiceUUID.Text := iplBLEClient1.ServiceUuid[Index];
    tbServiceId.Text := iplBLEClient1.ServiceId[Index];

    Index := GetCharacteristicIndex(tvGATTObjectsTree.Selected.Text);
    tbCharacteristicName.Text := iplBLEClient1.CharacteristicDescription[Index];
    tbCharacteristicUuid.Text := iplBLEClient1.CharacteristicUuid[Index];
    tbCharacteristicId.Text := iplBLEClient1.CharacteristicId[Index];
    TranslateFlags(iplBLEClient1.CharacteristicFlags[Index]);
    for I := 0 to FlagsList.Count-1 do
    begin
      Flags := Flags + FlagsList[I];
      if not(I = FlagsList.Count-1) then
        Flags := Flags + ', ';
    end;
    tbFlags.Text := Flags;
    btnReadValue.Enabled := HasFlag(iplBLEClient1.CharacteristicFlags[Index], CHAR_FLAG_READ);
    btnSubscribe.Enabled := iplBLEClient1.CharacteristicCanSubscribe[Index];
    if iplBLEClient1.CheckCharacteristicSubscribed(Index) then
    begin
      btnSubscribe.Caption := 'Unsubscribe';
    end;
  end
  else if tvGATTObjectsTree.Selected.Level = 3 then // Descriptors
  begin
    Index := GetServiceIndex(tvGATTObjectsTree.Selected.Parent.Parent.Text);
    tbServiceName.Text := iplBLEClient1.ServiceDescription[Index];
    tbServiceUUID.Text := iplBLEClient1.ServiceUuid[Index];
    tbServiceId.Text := iplBLEClient1.ServiceId[Index];

    Index := GetCharacteristicIndex(tvGATTObjectsTree.Selected.Parent.Text);
    tbCharacteristicName.Text := iplBLEClient1.CharacteristicDescription[Index];
    tbCharacteristicUuid.Text := iplBLEClient1.CharacteristicUuid[Index];
    tbCharacteristicId.Text := iplBLEClient1.CharacteristicId[Index];
    TranslateFlags(iplBLEClient1.CharacteristicFlags[Index]);
    for I := 0 to FlagsList.Count-1 do
    begin
      Flags := Flags + FlagsList[I];
      if not(I = FlagsList.Count-1) then
        Flags := Flags + ', ';
    end;
    tbFlags.Text := Flags;

    Index := GetDescriptorIndex(tvGATTObjectsTree.Selected.Text);
    tbDescriptorName.Text := iplBLEClient1.DescriptorDescription[Index];
    tbDescriptorUuid.Text := iplBLEClient1.DescriptorUuid[Index];
    tbDescriptorId.Text := iplBLEClient1.DescriptorId[Index];
    btnReadValue.Enabled := True;
    btnSubscribe.Enabled := False;
  end
  else                                              // Server, default
  begin
    tbServiceName.Text := '';
    tbServiceUUID.Text := '';
    tbServiceId.Text := '';
    tbCharacteristicName.Text := '';
    tbCharacteristicUuid.Text := '';
    tbCharacteristicId.Text := '';
    tbFlags.Text := '';
    tbDescriptorName.Text := '';
    tbDescriptorUuid.Text := '';
    tbDescriptorId.Text := '';
    btnReadValue.Enabled := False;
    btnSubscribe.Enabled := False;
  end;
end;

function TFormBLEClient.TBytesToHex(data: TBytes) : String;
var
  x: Integer;
begin
  for x := 0 to Length(data)-1 do
    Result := Result + IntToHex(data[x], 2);
end;

end.


