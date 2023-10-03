object FormBLEClient: TFormBLEClient
  Left = 0
  Top = 0
  Caption = 'BLEClient Demo'
  ClientHeight = 521
  ClientWidth = 1034
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object lblDemoIntro: TLabel
    Left = 8
    Top = 8
    Width = 1001
    Height = 26
    Caption = 
      'This demo shows how to use the BLEClient component. Start by sca' +
      'nning for available devices. If you want to connect to a device,' +
      ' choose it and click Connect. Once connected to a device, you ca' +
      'n browse its '#13#10'data, as well as subscribe to characteristics. Ho' +
      'ver over each tab to view more details about it.'
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clHighlight
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentColor = False
    ParentFont = False
  end
  object pcMainApplicationWindow: TPageControl
    Left = 8
    Top = 40
    Width = 1018
    Height = 473
    ActivePage = tsScanConnect
    TabOrder = 0
    object tsScanConnect: TTabSheet
      Caption = 'Scan and Connect'
      DesignSize = (
        1010
        445)
      object gbConnection: TGroupBox
        Left = 264
        Top = 3
        Width = 743
        Height = 54
        Caption = 'Connection'
        TabOrder = 2
        object lblServerIdConnect: TLabel
          Left = 11
          Top = 21
          Width = 50
          Height = 13
          Caption = 'Server ID:'
        end
        object lblCurrentlyConnectedTo: TLabel
          Left = 227
          Top = 21
          Width = 119
          Height = 13
          Caption = 'Currently Connected To:'
        end
        object tbServerIdConnect: TEdit
          Left = 67
          Top = 18
          Width = 142
          Height = 21
          TabOrder = 0
        end
        object tbCurrentlyConnectedTo: TEdit
          Left = 352
          Top = 18
          Width = 165
          Height = 21
          Enabled = False
          TabOrder = 1
          Text = '[Not Connected]'
        end
        object btConnect: TButton
          Left = 546
          Top = 16
          Width = 89
          Height = 25
          Caption = 'Connect'
          TabOrder = 2
          OnClick = btConnectClick
        end
        object btDisconnect: TButton
          Left = 641
          Top = 16
          Width = 89
          Height = 25
          Caption = 'Disconnect'
          TabOrder = 3
          OnClick = btDisconnectClick
        end
      end
      object gbScanning: TGroupBox
        Left = 3
        Top = 3
        Width = 246
        Height = 54
        Caption = 'Scanning'
        TabOrder = 0
        object btStartScanning: TButton
          Left = 9
          Top = 16
          Width = 89
          Height = 25
          Caption = 'Start Scanning'
          TabOrder = 0
          OnClick = btStartScanningClick
        end
        object cbUseActiveScanning: TCheckBox
          Left = 113
          Top = 16
          Width = 120
          Height = 25
          Caption = 'Use Active Scanning'
          TabOrder = 1
        end
      end
      object lvAdvertisements: TListView
        Left = 3
        Top = 63
        Width = 1004
        Height = 379
        Anchors = [akLeft, akTop, akRight, akBottom]
        Columns = <
          item
            Caption = 'Server ID'
            MinWidth = 10
            Width = 90
          end
          item
            Caption = 'Local Name'
            MinWidth = 10
            Width = 120
          end
          item
            Caption = 'RSSI'
            MinWidth = 10
            Width = 40
          end
          item
            Caption = 'TxPwr'
            MinWidth = 10
            Width = 45
          end
          item
            Caption = 'Connectable'
            MinWidth = 10
            Width = 72
          end
          item
            Caption = 'Service UUIDs'
            MinWidth = 10
            Width = 300
          end
          item
            Caption = 'Services With Data'
            MinWidth = 10
            Width = 105
          end
          item
            Caption = 'Mfr ID'
            MinWidth = 10
            Width = 60
          end
          item
            Caption = 'Manufacturer Data'
            MinWidth = 10
            Width = 300
          end>
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnSelectItem = lvAdvertisementsSelectItem
      end
    end
    object tsBrowseData: TTabSheet
      Caption = 'Browse Data'
      ImageIndex = 1
      object lblGATTObjectsTree: TLabel
        Left = 3
        Top = 3
        Width = 151
        Height = 13
        Caption = 'Discovered GATT Objects Tree:'
      end
      object tvGATTObjectsTree: TTreeView
        Left = 3
        Top = 22
        Width = 332
        Height = 420
        Indent = 19
        ReadOnly = True
        TabOrder = 0
        OnAddition = tvGATTObjectsTreeAddition
        OnClick = tvGATTObjectsTreeClick
      end
      object gbBrowseDataInfo: TGroupBox
        Left = 341
        Top = 22
        Width = 666
        Height = 420
        TabOrder = 1
        object gbDiscoverEverything: TGroupBox
          Left = 11
          Top = 84
          Width = 646
          Height = 48
          Caption = 'Discover Everything'
          TabOrder = 0
          object lblDiscoverEverythingWarning: TLabel
            Left = 17
            Top = 20
            Width = 433
            Height = 13
            Caption = 
              'If you wish to discover everything on the server at once you can' +
              '! (It may take some time)'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clHighlight
            Font.Height = -11
            Font.Name = 'Tahoma'
            Font.Style = []
            ParentFont = False
          end
          object btDiscoverEverything: TButton
            Left = 509
            Top = 15
            Width = 131
            Height = 25
            Caption = 'Discover Everything'
            TabOrder = 0
            OnClick = btDiscoverEverythingClick
          end
        end
        object gbServerInfo: TGroupBox
          Left = 11
          Top = 3
          Width = 646
          Height = 78
          Caption = 'Server Info'
          TabOrder = 1
          object lblServerIdBrowseData: TLabel
            Left = 17
            Top = 18
            Width = 50
            Height = 13
            Caption = 'Server ID:'
          end
          object lblServerName: TLabel
            Left = 17
            Top = 48
            Width = 66
            Height = 13
            Caption = 'Server Name:'
          end
          object tbServerIdBrowseData: TEdit
            Left = 89
            Top = 15
            Width = 551
            Height = 21
            Enabled = False
            TabOrder = 0
          end
          object tbServerName: TEdit
            Left = 89
            Top = 45
            Width = 551
            Height = 21
            Enabled = False
            TabOrder = 1
          end
        end
        object gbServiceInfo: TGroupBox
          Left = 11
          Top = 135
          Width = 646
          Height = 78
          Caption = 'Service Info'
          TabOrder = 2
          object lblServiceId: TLabel
            Left = 17
            Top = 22
            Width = 53
            Height = 13
            Caption = 'Service ID:'
          end
          object lblServiceName: TLabel
            Left = 252
            Top = 22
            Width = 69
            Height = 13
            Caption = 'Service Name:'
          end
          object lblServiceUUID: TLabel
            Left = 17
            Top = 49
            Width = 67
            Height = 13
            Caption = 'Service UUID:'
          end
          object tbServiceId: TEdit
            Left = 90
            Top = 19
            Width = 156
            Height = 21
            Enabled = False
            TabOrder = 0
          end
          object tbServiceUUID: TEdit
            Left = 90
            Top = 46
            Width = 550
            Height = 21
            Enabled = False
            TabOrder = 1
          end
          object tbServiceName: TEdit
            Left = 327
            Top = 19
            Width = 313
            Height = 21
            Enabled = False
            TabOrder = 2
          end
        end
        object gbCharacteristicInfo: TGroupBox
          Left = 11
          Top = 216
          Width = 646
          Height = 109
          Caption = 'Characteristic Info'
          TabOrder = 3
          object lblCharacteristicId: TLabel
            Left = 17
            Top = 20
            Width = 84
            Height = 13
            Caption = 'Characteristic ID:'
          end
          object lblCharacteristicName: TLabel
            Left = 391
            Top = 21
            Width = 100
            Height = 13
            Caption = 'Characteristic Name:'
          end
          object lblCharacteristicUuid: TLabel
            Left = 17
            Top = 48
            Width = 98
            Height = 13
            Caption = 'Characteristic UUID:'
          end
          object lblFlags: TLabel
            Left = 391
            Top = 48
            Width = 29
            Height = 13
            Caption = 'Flags:'
          end
          object tbCharacteristicId: TEdit
            Left = 106
            Top = 18
            Width = 279
            Height = 21
            Enabled = False
            TabOrder = 0
          end
          object tbCharacteristicName: TEdit
            Left = 497
            Top = 17
            Width = 143
            Height = 21
            Enabled = False
            TabOrder = 1
          end
          object tbCharacteristicUuid: TEdit
            Left = 121
            Top = 45
            Width = 264
            Height = 21
            Enabled = False
            TabOrder = 2
          end
          object tbFlags: TEdit
            Left = 426
            Top = 45
            Width = 214
            Height = 21
            Enabled = False
            TabOrder = 3
          end
          object btnSubscribe: TButton
            Left = 98
            Top = 76
            Width = 80
            Height = 25
            Caption = 'Subscribe'
            TabOrder = 4
            OnClick = btnSubscribeClick
          end
          object btnReadValue: TButton
            Left = 17
            Top = 76
            Width = 75
            Height = 25
            Caption = 'Read Value'
            TabOrder = 5
            OnClick = btnReadValueClick
          end
          object tbCharacteristicValue: TEdit
            Left = 184
            Top = 78
            Width = 456
            Height = 21
            Enabled = False
            TabOrder = 6
          end
        end
        object gbDescriptorInfo: TGroupBox
          Left = 11
          Top = 328
          Width = 646
          Height = 82
          Caption = 'Descriptor Info'
          TabOrder = 4
          object lblDescriptorName: TLabel
            Left = 17
            Top = 24
            Width = 83
            Height = 13
            Caption = 'Descriptor Name:'
          end
          object lblDescriptorUUID: TLabel
            Left = 19
            Top = 51
            Width = 81
            Height = 13
            Caption = 'Descriptor UUID:'
          end
          object lblDescriptorId: TLabel
            Left = 391
            Top = 24
            Width = 67
            Height = 13
            Caption = 'Descriptor ID:'
          end
          object tbDescriptorName: TEdit
            Left = 106
            Top = 21
            Width = 279
            Height = 21
            Enabled = False
            TabOrder = 0
          end
          object tbDescriptorUuid: TEdit
            Left = 106
            Top = 48
            Width = 534
            Height = 21
            Enabled = False
            TabOrder = 1
          end
          object tbDescriptorId: TEdit
            Left = 464
            Top = 21
            Width = 176
            Height = 21
            Enabled = False
            TabOrder = 2
          end
        end
      end
    end
  end
  object iplBLEClient1: TiplBLEClient
    OnAdvertisement = iplBLEClient1Advertisement
    OnConnected = iplBLEClient1Connected
    OnDisconnected = iplBLEClient1Disconnected
    OnDiscovered = iplBLEClient1Discovered
    OnSubscribed = iplBLEClient1Subscribed
    OnValue = iplBLEClient1Value
    Left = 984
    Top = 32
  end
end


