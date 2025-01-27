import SwiftUI
import IPWorksBLE

struct ContentView: View {
  var body: some View {
#if os(iOS)
        NavigationView {
          DeviceListView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
#else
    DeviceListView()
#endif
  }
}

struct DeviceListView: View, BLEClientDelegate {
  @ObservedObject var deviceManager = BLEDeviceManager()
  @ObservedObject var serviceInfoListManager: ServiceInfoListManager = ServiceInfoListManager()
  @ObservedObject var modificationManager: ModificationManager = ModificationManager()
  
  private var bleClient: BLEClient = BLEClient()
  
  init() {
    bleClient.delegate = self
    try! _ = bleClient.config(configurationString: "LogLevel=3")
  }
  
  var body: some View {
    VStack {
      if deviceManager.showingServiceExploreView {
        ServiceExploreView(bleClient: bleClient, deviceManager: deviceManager, serviceInfoListManager: serviceInfoListManager, modificationManager: modificationManager)
          .toolbar {
            ToolbarItem(placement: .automatic) {
              Button(action: {
                print("Disconnect button tapped")
                
                disconnect()
                deviceManager.showingServiceExploreView = false
              }) {
                Text("Disconnect")
              }
            }
          }
          .navigationTitle("Service Explore")
        
      } else {
        List(deviceManager.devices.indices, id: \.self) { index in
          VStack(alignment: .leading) {
            if !deviceManager.devices[index].name.isEmpty {
              Text(deviceManager.devices[index].name)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Text(deviceManager.devices[index].macAddress)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          
          .padding(.vertical, 10)
          .contentShape(Rectangle())
          .background(index % 2 == 0 ? Color.gray.opacity(0.2) : Color.clear)
          .onTapGesture {
            stopScan()
            connectDevice(serviceId: deviceManager.devices[index].macAddress)
          }
          
        }
        
        Spacer()
        
        Button(action: {
          startScan()
        }) {
          Text(deviceManager.isScanning ? "Stop scan" : "Start scan")
#if os(iOS)
            .font(.title)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
#endif
        }
        .padding(.bottom, 10)
        
        .alert(isPresented: $deviceManager.showingError, content: {
          Alert(title: Text(deviceManager.errorTitle), message: Text(deviceManager.errorMessage), dismissButton: .default(Text("OK")))
        })
      }
      
      
    }
    

    
    .overlay(
      Group {
        if deviceManager.showingProgress {
          ZStack {
            Color.black.opacity(0.4)
              .edgesIgnoringSafeArea(.all)
            VStack {
              ProgressView(deviceManager.progressMessage)
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .padding(50)
          }
        }
      }
    )
    
    .navigationTitle("BLE Devices")
    
  }
  
  func startScan() {
    do {
      print("Button clicked, isScanning: \(deviceManager.isScanning)")
      if deviceManager.isScanning {
        stopScan()
      } else {
        deviceManager.devices.removeAll()
        try bleClient.startScanning(serviceUuids: "")
      }
    } catch {
      print("Error starting/stopping scan: \(error)")
    }
  }
  
  func stopScan() {
    do {
      print("stopScan button clicked, isScanning: \(deviceManager.isScanning)")
      try bleClient.stopScanning()
      deviceManager.isScanning = false
    } catch {
      print("Error starting/stopping scan: \(error)")
    }
  }
  
  func connectDevice(serviceId: String) {
    deviceManager.showingProgress = true
    deviceManager.progressMessage = "Connecting..."
    serviceInfoListManager.serviceInfos.removeAll()
    
    DispatchQueue.global(qos: .background).async {
      do {
        defer {
          DispatchQueue.main.async {
            deviceManager.showingProgress = false
          }
        }

        bleClient.timeout = 10
        try bleClient.connect(serverId: serviceId)
        updateProgressMessage("Get services")
        try bleClient.discover(serviceUuids: "", characteristicUuids: "", discoverDescriptors: true, includedByServiceId: "")
        updateProgressMessage("Get services details")
        for service in bleClient.services {
          var serviceDescription = service.description_
          if serviceDescription.isEmpty {
            serviceDescription = Utils.getDescFromUUID(uuid: service.uuid)
          }
          if serviceDescription.isEmpty {
            serviceDescription = "Unknown Service"
          }
          
          let serviceUUID = service.uuid
          bleClient.service = service.id
          var myCharacteristics: [MyCharacteristic] = []
          var characteristicIndex:Int32 = 0
          
          updateProgressMessage("Get services details for \(serviceDescription) [\(serviceId)]")
          for characteristic in bleClient.characteristics {
            print("characteristic UUID: \(characteristic.uuid)")
            bleClient.characteristic = characteristic.uuid
            do {
              if Utils.isReadable(characteristic: characteristic) {
                try _ = bleClient.readValue(serviceId: service.id, characteristicId: characteristic.id,
                                            descriptorId: "")
              }

              let characteristicDesc = characteristic.description_
              print("Found: \(serviceDescription) [\(serviceUUID)] - \(characteristicDesc)")
              if Utils.isReadable(characteristic: characteristic) {
                for descriptor in bleClient.descriptors {
                  try _ = bleClient.readValue(serviceId: service.id, characteristicId: characteristic.id, descriptorId: descriptor.id)
                }
              } else {
                print("Descriptors are ignored due to no readable.")
              }
              
              let myCharacteristic = DeviceListView.loadCharacteristic(bleClient: bleClient, serviceId: service.id, characteristicIndex: characteristicIndex, subscribing: false)
              myCharacteristics.append(myCharacteristic)
            } catch let e {
              print("readValue error: \(e)")
            }
            characteristicIndex += 1
          }
          
          let serviceInfo = MyServiceInfo(serviceId: service.id, serviceDescription: serviceDescription, uuid: service.uuid, characteristics: myCharacteristics)
          DispatchQueue.main.async {
            serviceInfoListManager.serviceInfos.append(serviceInfo)
          }
        }
        
        DispatchQueue.main.async {
          deviceManager.showingServiceExploreView = true
        }
        
      } catch let ex {
        showAlert("Unknow Error", ex.localizedDescription)
      }
    }
  }
  
  func disconnect() {
    DispatchQueue.global(qos: .background).async {
      try? bleClient.disconnect()
    }
  }
  
  func updateProgressMessage(_ msg: String) {
    DispatchQueue.main.async {
      deviceManager.progressMessage = msg
    }
  }
  
  func showAlert(_ title: String, _ msg: String) {
    print("Show Alert: \(title), \(msg)")

    DispatchQueue.main.async {
      if (deviceManager.showingError) {
        deviceManager.errorMessage = "\(deviceManager.errorMessage)\n\n\(title)\n\(msg)"
      } else {
        deviceManager.errorTitle = title
        deviceManager.errorMessage = msg
      }
      deviceManager.showingError = true
    }
  }
  
  static func loadCharacteristic(bleClient: BLEClient, serviceId: String, characteristicIndex: Int32, subscribing: Bool) -> MyCharacteristic {
    let characteristic = bleClient.characteristics[Int(characteristicIndex)]
    let characteristicValue = Utils.encodeValue(bleClient: bleClient, serviceId: serviceId, characteristicsIndex: characteristicIndex)
    
    var myDescriptors: [MyDescriptor] = []
    for descriptor in bleClient.descriptors {
      let myDescriptor = MyDescriptor(description_: descriptor.description_, uuid: descriptor.uuid)
      myDescriptors.append(myDescriptor)
    }
    
    let characteristicDesc = Utils.getDescription(characteristic: characteristic)
    let myCharacteristic = MyCharacteristic(characteristicId: characteristic.id, characteristicIndex: characteristicIndex, description_: characteristicDesc, flags: characteristic.flags, uuid: characteristic.uuid, cachedValue: characteristicValue, canSubscribe: characteristic.canSubscribe, subscribing: subscribing, descriptors: myDescriptors)
    return myCharacteristic
  }
  
  func onAdvertisement(serverId: String, name: String, rssi: Int32, txPower: Int32, serviceUuids: String, servicesWithData: String, solicitedServiceUuids: String, manufacturerCompanyId: Int32, manufacturerData: Data, isConnectable: Bool, isScanResponse: Bool) {
    print("[Advertisement] serverId: \(serverId), name: \(name), rssi: \(rssi), isConnectable: \(isConnectable)")
    DispatchQueue.main.async {
      
      self.deviceManager.addDevice(serverId: serverId, name: name)
    }
  }
  
  func onConnected(statusCode: Int32, description: String) {
    print("[Connected] \(statusCode) \(description)")
    if statusCode != 0 {
      // connection error
      showAlert("Connection Error", description)
    }
  }
  
  func onDisconnected(statusCode: Int32, description: String) {
    print("[Disconnected] \(statusCode) \(description)")
    if statusCode != 0 {
      showAlert("Disconnected", description)
    }
  }
  
  func onDiscovered(gattType: Int32, serviceId: String, characteristicId: String, descriptorId: String, uuid: String, description: String) {
    print("[Discovered] gattType: \(gattType), serviceId: \(serviceId), characteristicId: \(characteristicId), descriptorId: \(descriptorId), uuid: \(uuid), description: \(description)")
    
  }
  
  func onError(errorCode: Int32, description: String) {
    let msg = "Code: \(errorCode), \(description)"
    print("[Error] \(msg)")
    showAlert("Error", msg)
  }
  
  func onLog(logLevel: Int32, message: String, logType: String) {
    print("[Log] [" + logType + "] "  + message)
  }
  
  func onPairingRequest(serverId: String, pairingKind: Int32, pin: inout String, accept: inout Bool) {
    print("[PairingRequest] serverId: \(serverId), pairingKind: \(pairingKind), pin: \(pin)")
  }
  
  func onServerUpdate(name: String, changedServices: String) {
    print("[ServerUpdate] name: \(name), changedServices: \(changedServices)")
  }
  
  func onStartScan(serviceUuids: String) {
    print("[StartScan] \(serviceUuids)")
    DispatchQueue.main.async {
      deviceManager.isScanning = true
    }
  }
  
  func onStopScan(errorCode: Int32, errorDescription: String) {
    print("[StopScan] code: \(errorCode), description: \(errorDescription)")
    DispatchQueue.main.async {
      deviceManager.isScanning = false
    }
  }
  
  func onSubscribed(serviceId: String, characteristicId: String, uuid: String, description: String) {
    print("[Subscribed] serviceId: \(serviceId), characteristicId: \(characteristicId), uuid: \(uuid), description: \(description)")
    
  }
  
  func onUnsubscribed(serviceId: String, characteristicId: String, uuid: String, description: String) {
    print("[Unsubscribed] serviceId: \(serviceId), characteristicId: \(characteristicId), uuid: \(uuid), description: \(description)")
  }
  
  func onValue(serviceId: String, characteristicId: String, descriptorId: String, uuid: String, description: String, value: Data) {
    print("[Value] serviceId: \(serviceId), characteristicId: \(characteristicId), descriptorId:\(descriptorId), uuid: \(uuid), description: \(description)")
    
    guard deviceManager.showingServiceExploreView else {
      return
    }
    
    guard !modificationManager.showModifyView else {
      return
    }
    
    // search
    if let serviceIndex = serviceInfoListManager.serviceInfos.firstIndex(where: { $0.serviceId == serviceId }) {
      if let characteristics = serviceInfoListManager.serviceInfos[serviceIndex].characteristics {
        if let characteristicIndex = characteristics.firstIndex(where: { $0.characteristicId == characteristicId}) {
          let characteristic = characteristics[characteristicIndex]
          if characteristic.subscribing {
            
            let newValue = Utils.encodeValue(bleClient: bleClient, serviceId: serviceId, characteristicsIndex: characteristic.characteristicIndex)
            if characteristic.cachedValue != newValue {
              
              // update UI
              DispatchQueue.main.async {
                serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].cachedValue = newValue
              }
            }
          }
        }
      }
    }
  
  }
  
  func onWriteResponse(serviceId: String, characteristicId: String, descriptorId: String, uuid: String, description: String) {
    print("[WriteResponse] serviceId: \(serviceId), characteristicId: \(characteristicId), descriptorId: \(descriptorId), uuid: \(uuid), description: \(description)")
    
  }
}


struct DeviceListView_Previews: PreviewProvider {
  static var previews: some View {
    let view = DeviceListView()
    view.deviceManager.addDevice(serverId: "00:11:22:33:44:55", name: "Test Device 1")
    view.deviceManager.addDevice(serverId: "11:22:33:44:55:66", name: "Test Device 2")
    view.deviceManager.addDevice(serverId: "22:33:44:55:66:77", name: "")
    view.deviceManager.addDevice(serverId: "33:44:55:66:77:88", name: "Test Device 4")
    return view
  }
}


struct ServiceExploreView: View {
  @ObservedObject var serviceInfoListManager: ServiceInfoListManager
  @ObservedObject var modificationManager: ModificationManager
  @ObservedObject var deviceManager: BLEDeviceManager
  private var bleClient: BLEClient
  
  init(bleClient: BLEClient, deviceManager: BLEDeviceManager, serviceInfoListManager: ServiceInfoListManager, modificationManager: ModificationManager) {
    self.bleClient = bleClient
    self.deviceManager = deviceManager
    self.serviceInfoListManager = serviceInfoListManager
    self.modificationManager = modificationManager
  }
  
  var body: some View {
    List(serviceInfoListManager.serviceInfos) { serviceInfo in
      VStack(alignment: .leading) {
        Text(serviceInfo.serviceDescription )
          .font(.headline)
          .bold()
        Text("UUID: \(serviceInfo.uuid)")
          .foregroundColor(.gray)
          
        if serviceInfo.characteristics != nil {
          ForEach(serviceInfo.characteristics!.indices, id: \.self) { characteristicIndex in
            VStack(alignment: .leading) {
              HStack {
                Text(serviceInfo.characteristics![characteristicIndex].description_)
                  .font(.headline)
                Spacer()
                if serviceInfo.characteristics![characteristicIndex].canSubscribe {
                  Image(systemName: "bell")
                    .background(serviceInfo.characteristics![characteristicIndex].subscribing ? Color.blue : Color.clear)
                    .onTapGesture {
                      tapSubscribe(characteristicIndex: characteristicIndex, serviceInfo: serviceInfo)
                    }
                }
 
                if Utils.isReadable(characteristicFlags: serviceInfo.characteristics![characteristicIndex].flags) {
                  Image(systemName: "arrow.clockwise")
                    .onTapGesture {
                      let currentServiceId = serviceInfo.serviceId
                      let myCharacteristics = serviceInfo.characteristics!
                      let idx = characteristicIndex
                      refreshCharacteristic(serviceId: currentServiceId, characteristics:myCharacteristics, myCharacteristicIndex: idx) { newCharacteristic in
                        DispatchQueue.main.async {
                          if let serviceIndex = serviceInfoListManager.serviceInfos.firstIndex(where: { $0.uuid == serviceInfo.uuid }) {
                            serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].description_ = newCharacteristic.description_
                            serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].flags = newCharacteristic.flags
                            serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].uuid = newCharacteristic.uuid
                            serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].cachedValue = newCharacteristic.cachedValue
                            serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].canSubscribe = newCharacteristic.canSubscribe
                            serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].descriptors = newCharacteristic.descriptors
                          }
                          
                        }
                      }
                    }
                }
                
                if Utils.isWriteable(characteristicFlags: serviceInfo.characteristics![characteristicIndex].flags) {
                  Image(systemName: "pencil")
                    .onTapGesture {
                      
                      let currentServiceId = serviceInfo.serviceId
                      let myCharacteristics = serviceInfo.characteristics!
                      let uuid = serviceInfo.uuid
                      modify(serviceId: currentServiceId, serviceUuid: uuid, characteristics:myCharacteristics, myCharacteristicIndex: characteristicIndex)
                    }
                }
                
              }
              Text("UUID: \(serviceInfo.characteristics![characteristicIndex].uuid)")
              Text("Properties: \(Utils.getPropertiesDesc(serviceInfo.characteristics![characteristicIndex].flags))")
              Text("Value: \(serviceInfo.characteristics![characteristicIndex].cachedValue)")
              if !serviceInfo.characteristics![characteristicIndex].descriptors.isEmpty {
                VStack(alignment: .leading) {
                  HStack {
                    Text("Descriptors:")
                      .fontWeight(.semibold)
                     
                    Spacer()
                  }
                  ForEach(serviceInfo.characteristics![characteristicIndex].descriptors, id: \.id) { descriptor in
                    VStack(alignment: .leading) {
                      Text("UUID: \(descriptor.uuid)")
                      Text("Description: \(descriptor.description_)")
                    }
                  }
                }
                .padding(.leading)
              }
            }
            .padding(.leading)
          }
        }
      }
    }
    
    .alert(isPresented: $deviceManager.showingError, content: {
      Alert(title: Text(deviceManager.errorTitle), message: Text(deviceManager.errorMessage), dismissButton: .default(Text("OK")))
    })
    
    .sheet(isPresented: $modificationManager.showModifyView) {
      ModifyView(modificationManager: modificationManager, bleClient: bleClient, onModifyFinished: {
        modifyFinished()
      })
    }
    

    
  }
  
  func tapSubscribe(characteristicIndex: Int, serviceInfo: MyServiceInfo) {
    DispatchQueue.global(qos: .background).async {
      if let serviceIndex = serviceInfoListManager.serviceInfos.firstIndex(where: { $0.uuid == serviceInfo.uuid }) {
        let subscribing = serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].subscribing
        DispatchQueue.main.async {
          serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].subscribing.toggle()
        }
        
        if subscribing {
          if !unsubscribe(serviceId: serviceInfo.serviceId, characteristicId: serviceInfo.characteristics![characteristicIndex].characteristicId) {
            DispatchQueue.main.async {
              serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].subscribing.toggle()
            }
          }
        } else {
          if !subscribe(serviceId: serviceInfo.serviceId, characteristicId: serviceInfo.characteristics![characteristicIndex].characteristicId) {
            DispatchQueue.main.async {
              serviceInfoListManager.serviceInfos[serviceIndex].characteristics![characteristicIndex].subscribing.toggle()
            }
          }
        }
      }
    }
  }
  
  
  func subscribe(serviceId: String, characteristicId: String) -> Bool {
    print("Subscribe serviceId:\(serviceId), characteristicId:\(characteristicId)")
    do {
      try bleClient.subscribe(serviceId: serviceId, characteristicId: characteristicId)
      return true
    } catch let e {
      reportError("Subscribe Error", "\(e)")
    }
    return false
  }
  
  func unsubscribe(serviceId: String, characteristicId: String) -> Bool {
    print("Unsubscribe serviceId:\(serviceId), characteristicId:\(characteristicId)")
    do {
      try bleClient.unsubscribe(serviceId: serviceId, characteristicId: characteristicId)
      return true
    } catch let e {
      reportError("Unsubscribe Error", "\(e)")
    }
    return false
  }
  
  func refreshCharacteristic(serviceId: String, characteristics: [MyCharacteristic], myCharacteristicIndex: Int, completion: @escaping(MyCharacteristic) -> Void) {
    print("Refresh Characteristic. serviceId: \(serviceId), myCharacteristicIndex: \(myCharacteristicIndex)")
    DispatchQueue.global(qos: .background).async {
      do {
        let characteristic = characteristics[myCharacteristicIndex]
        try _ = bleClient.readValue(serviceId: serviceId, characteristicId: characteristic.characteristicId, descriptorId: "")
        
        // service and characteristic are required
        bleClient.service = serviceId
        bleClient.characteristic = characteristic.characteristicId
        let newCharacteristic = DeviceListView.loadCharacteristic(bleClient: bleClient, serviceId: serviceId, characteristicIndex: characteristic.characteristicIndex, subscribing: characteristic.subscribing)
        completion(newCharacteristic)
      } catch let e {
        reportError("Refresh Characteristic Error", "\(e)")
      }
    }
  }
  
  
  func modify(serviceId: String, serviceUuid: String, characteristics: [MyCharacteristic], myCharacteristicIndex: Int) {
    print("Modify serviceId: \(serviceId), myCharacteristicIndex: \(myCharacteristicIndex)")

    let characteristic = characteristics[myCharacteristicIndex]
    let oldValue = characteristic.cachedValue
    
    modificationManager.oldValue = oldValue
    modificationManager.newValue = oldValue
    modificationManager.serviceId = serviceId
    modificationManager.serviceUuid = serviceUuid
    modificationManager.characteristicId = characteristic.characteristicId
    modificationManager.characteristicIndex = characteristic.characteristicIndex
    modificationManager.descriptorId = ""
    modificationManager.showModifyView = true

  }
  
  func modifyFinished() {
    print("Modify finished ")
    // refresh UI
    if let serviceIndex = serviceInfoListManager.serviceInfos.firstIndex(where: { $0.uuid == modificationManager.serviceUuid }) {
      DispatchQueue.main.async {
        serviceInfoListManager.serviceInfos[serviceIndex].characteristics![Int(modificationManager.characteristicIndex)].cachedValue = modificationManager.newValue
      }
    }
  }
  
  
  func reportError(_ title: String, _ msg: String) {
    print("Report error: \(title), \(msg)")
    
    DispatchQueue.main.async {
      if (deviceManager.showingError) {
        deviceManager.errorMessage = "\(deviceManager.errorMessage)\n\n\(title)\n\(msg)"
      } else {
        deviceManager.errorTitle = title
        deviceManager.errorMessage = msg
      }
      deviceManager.showingError = true
    }
  }
  
  func disconnect() {
    DispatchQueue.global(qos: .background).async {
      try? bleClient.disconnect()
    }
  }
  
}

struct ServiceExploreView_Previews: PreviewProvider {
  static var previews: some View {
    // some demo data
    let descriptors = [
      MyDescriptor(description_: "MyDescriptor 1", uuid: "1234"),
      MyDescriptor(description_: "MyDescriptor 2", uuid: "5678")
    ]
    
    let MyCharacteristics = [
      MyCharacteristic(characteristicId: "1234", characteristicIndex: 0, description_: "MyCharacteristic 1", flags: 65535, uuid: "abcd", cachedValue: "Value 1", canSubscribe: true, subscribing: false, descriptors: descriptors),
      MyCharacteristic(characteristicId: "2234", characteristicIndex: 1, description_: "MyCharacteristic 2", flags: 2, uuid: "efgh", cachedValue: "Value 2", canSubscribe: false, subscribing: false, descriptors: [])
    ]
    
    let serviceInfos = [
      MyServiceInfo(serviceId: "12345", serviceDescription: "Service 1", uuid: "1111", characteristics: MyCharacteristics),
      MyServiceInfo(serviceId: "123467", serviceDescription: "Service 2", uuid: "2222", characteristics: nil)
    ]
    
    let serviceInfoListManager = ServiceInfoListManager()
    serviceInfoListManager.serviceInfos = serviceInfos
    let deviceManager = BLEDeviceManager()
    deviceManager.showingServiceExploreView = true
    let modificationManager = ModificationManager()
    let view = ServiceExploreView(bleClient: BLEClient(), deviceManager: deviceManager, serviceInfoListManager: serviceInfoListManager, modificationManager: modificationManager)
    return view
  }
}


struct ModifyView: View {
  @ObservedObject var modificationManager: ModificationManager
  var bleClient: BLEClient
  var onModifyFinished: () -> Void
  @State var showingError = false
  @State var errorTitle = ""
  @State var errorMessage = ""
  
  var body: some View {
    VStack {
      Text("Write Value")
        .font(.headline)
        .padding()
      
      TextEditor(text: $modificationManager.newValue)
        .padding()
        .frame(height: 100)
        .border(Color.gray, width: 1)
        .padding()
      
      HStack {
        Spacer()
        Button("Write") {
          modify()
        }
        .padding()
        
        Spacer()
        
        Button("Cancel") {
          modificationManager.showModifyView = false
        }
        .padding()
        Spacer()
      }
      .padding()
    }
    .padding()
    
    .alert(isPresented: $showingError, content: {
      Alert(title: Text(errorTitle), message: Text(errorMessage), dismissButton: .default(Text("OK")))
    })
  }
  
  private func modify() {
    DispatchQueue.global(qos: .background).async {
      do {
        if modificationManager.oldValue != modificationManager.newValue {
          bleClient.service = modificationManager.serviceId
          let characteristic = bleClient.characteristics[Int(modificationManager.characteristicIndex)]
          let newValueDate = Utils.decodeValue(characteristic: characteristic, val: modificationManager.newValue)
          try bleClient.writeValue(serviceId: modificationManager.serviceId, characteristicId: modificationManager.characteristicId, descriptorId: modificationManager.descriptorId, value: newValueDate)
        }
        DispatchQueue.main.async {
          modificationManager.showModifyView = false
        }
        onModifyFinished()
      } catch let e {
        print("Failed to modify: \(e)")
        DispatchQueue.main.async {
          errorTitle = "Failed to Modify"
          errorMessage = "\(e)"
          showingError = true
        }
      }
    }
  }
  
}


struct ModifyView_Previews: PreviewProvider {
  static var previews: some View {
    let modificationManager = ModificationManager()
    modificationManager.showModifyView = true
    modificationManager.newValue = "Test"
    
    return ModifyView(modificationManager: modificationManager, bleClient: BLEClient(), onModifyFinished: {
      
    })
  }
}





struct BLEDevice: Identifiable {
  let id = UUID()
  let macAddress: String
  var name: String
}

class BLEDeviceManager: ObservableObject {
  @Published var devices: [BLEDevice] = []
  @Published var isScanning = false
  @Published var showingProgress = false
  @Published var progressMessage: String = ""
  @Published var showingServiceExploreView = false
  @Published var showingError = false
  @Published var errorTitle: String = ""
  @Published var errorMessage: String = ""
  
  
  func addDevice(serverId: String, name: String) {
    DispatchQueue.main.async {
      
      if let idx = self.devices.firstIndex(where: { $0.macAddress == serverId }) {
        if !name.isEmpty && self.devices[idx].name != name {
          self.devices[idx].name = name
        }
      } else {
        let newDevice = BLEDevice(macAddress: serverId, name: name)
        self.devices.append(newDevice)
        print("Device added: \(serverId), \(name)")
      }
    }
  }
}

class ServiceInfoListManager: ObservableObject {
  @Published var serviceInfos: [MyServiceInfo] = []
}

class ModificationManager: ObservableObject {
  @Published var showModifyView = false
  @Published var serviceId: String = ""
  @Published var serviceUuid: String = ""
  @Published var characteristicId: String = ""
  @Published var characteristicIndex: Int32 = 0
  @Published var descriptorId: String = ""
  @Published var oldValue: String = ""
  @Published var newValue: String = ""
}


struct MyServiceInfo: Identifiable {
  let id = UUID()
  let serviceId: String
  let serviceDescription: String
  let uuid: String
  var characteristics: [MyCharacteristic]?
}

struct MyCharacteristic: Identifiable {
  let id = UUID()
  var characteristicId: String
  var characteristicIndex: Int32
  var description_: String
  var flags: Int32
  var uuid: String
  var cachedValue: String
  var canSubscribe: Bool
  var subscribing: Bool
  var descriptors: [MyDescriptor]
}

struct MyDescriptor: Identifiable {
  let id = UUID()
  var description_: String
  var uuid: String
}



class Utils {
  static let VALUE_FORMAT_UNKNOW = 0
  static let VALUE_FORMAT_STRING = 1
  static let VALUE_FORMAT_HEX = 2
  static let VALUE_FORMAT_INT = 3
  static let VALUE_FORMAT_FLOAT = 4

  private static func getUUIDTag(uuid: String) -> String {
    return String(uuid[uuid.index(uuid.startIndex, offsetBy: 4)..<uuid.index(uuid.startIndex, offsetBy: 8)])
  }
  
  static func getDescFromUUID(uuid: String) -> String {
    let uuid = uuid.uppercased()
    let tag = getUUIDTag(uuid: uuid)
    
    var ret = ""
    if uuid.hasPrefix("0000") && uuid.hasSuffix("-0000-1000-8000-00805F9B34FB") {
      ret = getUUIDDesc(map: COMMON_UUID, uuidTag: tag)
    } else if uuid.hasPrefix("F000") && uuid.hasSuffix("-0451-4000-B000-000000000000") {
      ret = getUUIDDesc(map: CC2650_UUID, uuidTag: tag)
    } else if uuid.hasPrefix("A000") && uuid.hasSuffix("-0000-1000-8000-00805F9B34FB") {
      ret = getUUIDDesc(map: MYTEST_UUID, uuidTag: tag)
    }
    
    return ret
  }
  
  static func getValueFormat(uuid: String) -> Int {
    let uuid = uuid.uppercased()
    let tag = getUUIDTag(uuid: uuid)
    if uuid.hasPrefix("0000") && uuid.hasSuffix("-0000-1000-8000-00805F9B34FB") {
      return getUUIDValFormat(map: COMMON_FORMAT_UUID, uuidTag: tag)
    } else if uuid.hasPrefix("F000") && uuid.hasSuffix("-0451-4000-B000-000000000000") {
      return getUUIDValFormat(map: CC2650_FORMAT_UUID, uuidTag: tag)
    } else if uuid.hasPrefix("A000") && uuid.hasSuffix("-0000-1000-8000-00805F9B34FB") {
      return getUUIDValFormat(map: MYTEST_FORMAT_UUID, uuidTag: tag)
    }
    return VALUE_FORMAT_HEX
  }
  
  private static func getUUIDDesc(map: [[String]], uuidTag: String) -> String {
    for item in map {
      if item[0].caseInsensitiveCompare(uuidTag) == .orderedSame {
        return item[1]
      }
    }
    return ""
  }
  
  static func isWriteable(characteristic: Characteristic) -> Bool {
    return isWriteable(characteristicFlags: characteristic.flags)
  }
  static func isWriteable(characteristicFlags: Int32) -> Bool {
    return (characteristicFlags & 0x00000008) != 0 || (characteristicFlags & 0x00000004) != 0
  }
  
  static func isReadable(characteristic: Characteristic) -> Bool {
    return isReadable(characteristicFlags: characteristic.flags)
  }
  static func isReadable(characteristicFlags: Int32) -> Bool {
    return (characteristicFlags & 0x00000002) != 0
  }
  
  static func isNotifiable(characteristicFlags: Int32) -> Bool {
    return (characteristicFlags & 0x00000010) != 0
  }
  
  static func getPropertiesDesc(_ characteristicFlags: Int32) -> String {
    var desc = ""
    if isReadable(characteristicFlags: characteristicFlags) {
      desc += "Read"
    }
    if isWriteable(characteristicFlags: characteristicFlags) {
      if !desc.isEmpty {
        desc += ", "
      }
      desc += "Write"
    }
    if isNotifiable(characteristicFlags: characteristicFlags) {
      if !desc.isEmpty {
        desc += ", "
      }
      desc += "Notify"
    }
    
      return desc
  }
  
  static func getDescription(characteristic: Characteristic) -> String {
    var characteristicDesc = characteristic.description_
    if characteristicDesc.isEmpty {
      characteristicDesc = Utils.getDescFromUUID(uuid: characteristic.uuid)
    }
    if characteristicDesc.isEmpty {
      characteristicDesc = "Unknown Characteristic"
    }
    return characteristicDesc
  }
  
  static func encodeValue(bleClient: BLEClient, serviceId: String, characteristicsIndex: Int32) -> String {
    do {
      bleClient.service = serviceId
      let characteristic = bleClient.characteristics[Int(characteristicsIndex)]
      let value = try bleClient.queryCharacteristicCachedVal(index: Int32(characteristicsIndex))
      let format = getValueFormat(uuid: characteristic.uuid)
      if format == VALUE_FORMAT_STRING {
        return String(data: value, encoding: .utf8) ?? ""
      } else if format == VALUE_FORMAT_INT || format == VALUE_FORMAT_FLOAT {
        //let intFormat = characteristic.valueFormat
        // todo: decode int/float value
      }
      return Utils.bytesToHexString(data: value)
    } catch let error as IPWorksBLEError {
      return error.localizedDescription
    } catch {
      return "Unknown error"
    }
  }
  
  static func decodeValue(characteristic: Characteristic, val: String) -> Data {
    let format = getValueFormat(uuid: characteristic.uuid)
    if format == VALUE_FORMAT_STRING {
      return val.data(using: .utf8) ?? Data()
    } else if format == VALUE_FORMAT_INT || format == VALUE_FORMAT_FLOAT {
      //let intFormat = characteristic.valueFormat
      // todo: encode int/float value
    }
    return hexStringToByteArray(hexString: val)
  }
  
  private static func getUUIDValFormat(map: [[String]], uuidTag: String) -> Int {
    for item in map {
      if item[0].caseInsensitiveCompare(uuidTag) == .orderedSame {
        switch item[1] {
        case "STRING":
          return VALUE_FORMAT_STRING
        case "INT":
          return VALUE_FORMAT_INT
        case "FLOAT":
          return VALUE_FORMAT_FLOAT
        default:
          return VALUE_FORMAT_HEX
        }
      }
    }
    return VALUE_FORMAT_HEX
  }
  
  static func bytesToHexString(data: Data) -> String {
    return data.map { String(format: "%02x", $0) }.joined()
  }
  
  static func hexStringToByteArray(hexString: String) -> Data {
    var data = Data()
    var hex = hexString
    while hex.count > 0 {
      let c = String(hex.prefix(2))
      hex = String(hex.dropFirst(2))
      var ch: UInt64 = 0
      Scanner(string: c).scanHexInt64(&ch)
      var char = UInt8(ch)
      data.append(&char, count: 1)
    }
    return data
  }
  
  
  static let MYTEST_FORMAT_UUID = [
    ["1001", "STRING"],
    ["1002", "INT"],
    ["1010", "STRING"],
    ["1011", "STRING"],
  ];
  
  static let MYTEST_UUID = [
    ["1000", "BLE Test Service"],
    ["1001", "A String characteristic"],
    ["1002", "A Int characteristic"],
    ["1010", "A read/write descriptor"],
    ["1011", "A readonly descriptor"],
  ];
  
  static let CC2650_FORMAT_UUID = [
    ["2A00", "STRING"],
    ["2A24", "STRING"],
    ["2A25", "STRING"],
    ["2A26", "STRING"],
    ["2A27", "STRING"],
    ["2A28", "STRING"],
    ["2A29", "STRING"],
    ["AA02", "INT"],
    ["AA03", "INT"],
    ["AA22", "INT"],
    ["AA23", "INT"],
    ["AA42", "INT"],
    ["AA44", "INT"],
    ["AA83", "INT"],
    ["AA72", "INT"],
    ["AA73", "INT"],
  ];
  static let CC2650_UUID = [
    ["1800", "Generic Access Service"],
    ["2A00", "Device Name"],
    ["2A01", "Appearance"],
    ["2A04", "Peripheral Preferred Connection Parameters"],
    ["1801", "Generic Attribute Service"],
    ["2A05", "Service Changed "],
    ["180A", "Device Information Service"],
    ["2A23", "System ID"],
    ["2A24", "Model Number String"],
    ["2A25", "Serial Number String"],
    ["2A26", "Firmware Revision String"],
    ["2A27", "Hardware Revision String"],
    ["2A28", "Software Revision String"],
    ["2A29", "Manufacturer Name String"],
    ["2A2A", "IEEE 11073-20601 Regulatory Certification Data List"],
    ["2A50", "PnP ID"],
    ["AA00", "IR Temperature Service"],
    ["AA01", "IR Temperature Data"],
    ["AA02", "IR Temperature Config"],
    ["AA03", "IR Temperature Period"],
    ["AA20", "Humidity Service"],
    ["AA21", "Humidity Data"],
    ["AA22", "Humidity Config"],
    ["AA23", "Humidity Period"],
    ["AA40", "Barometer Service"],
    ["AA41", "Barometer Data"],
    ["AA42", "Barometer Configuration"],
    ["AA44", "Barometer Period"],
    ["AA80", "Movement Service"],
    ["AA81", "Movement Data"],
    ["AA82", "Movement Config"],
    ["AA83", "Movement Period"],
    ["AA70", "Luxometer Service"],
    ["AA71", "Luxometer Data"],
    ["AA72", "Luxometer Config"],
    ["AA73", "Luxometer Period"],
    ["AA64", "IO Service"],
    ["AA65", "IO Data"],
    ["AA66", "IO Config"],
    ["AC00", "Register Service"],
    ["AC01", "Register Data"],
    ["AC02", "Register Address"],
    ["AC03", "Register Device ID"],
    ["CCC0", "Connection Control Service"],
    ["CCC1", "Connection Parameters"],
    ["CCC2", "Request Connection Parameters "],
    ["CCC3", "Disconnect request  "],
    ["FFC0", "OAD Service"],
    ["FFC1", "OAD Image Identify"],
    ["FFC2", "OAD Image Block"],
  ];
  
  static let COMMON_FORMAT_UUID = [
    ["2a8a", "STRING"],
    ["2a90", "STRING"],
    ["2ab5", "STRING"],
    ["2abe", "STRING"],
    ["2a00", "STRING"],
    ["2a24", "STRING"],
    ["2a25", "STRING"],
    ["2a26", "STRING"],
    ["2a27", "STRING"],
    ["2a28", "STRING"],
    ["2a29", "STRING"],
    ["2a19", "INT"],
    
  ];
  static let COMMON_UUID = [
    ["0001", "SDP"],
    ["0003", "RFCOMM"],
    ["0005", "TCS-BIN"],
    ["0007", "ATT"],
    ["0008", "OBEX"],
    ["000f", "BNEP"],
    ["0010", "UPNP"],
    ["0011", "HIDP"],
    ["0012", "Hardcopy Control Channel"],
    ["0014", "Hardcopy Data Channel"],
    ["0016", "Hardcopy Notification"],
    ["0017", "AVCTP"],
    ["0019", "AVDTP"],
    ["001b", "CMTP"],
    ["001e", "MCAP Control Channel"],
    ["001f", "MCAP Data Channel"],
    ["0100", "L2CAP"],
    ["1000", "Service Discovery Server Service Class"],
    ["1001", "Browse Group Descriptor Service Class"],
    ["1002", "Public Browse Root"],
    ["1101", "Serial Port"],
    ["1102", "LAN Access Using PPP"],
    ["1103", "Dialup Networking"],
    ["1104", "IrMC Sync"],
    ["1105", "OBEX Object Push"],
    ["1106", "OBEX File Transfer"],
    ["1107", "IrMC Sync Command"],
    ["1108", "Headset"],
    ["1109", "Cordless Telephony"],
    ["110a", "Audio Source"],
    ["110b", "Audio Sink"],
    ["110c", "A/V Remote Control Target"],
    ["110d", "Advanced Audio Distribution"],
    ["110e", "A/V Remote Control"],
    ["110f", "A/V Remote Control Controller"],
    ["1110", "Intercom"],
    ["1111", "Fax"],
    ["1112", "Headset AG"],
    ["1113", "WAP"],
    ["1114", "WAP Client"],
    ["1115", "PANU"],
    ["1116", "NAP"],
    ["1117", "GN"],
    ["1118", "Direct Printing"],
    ["1119", "Reference Printing"],
    ["111a", "Basic Imaging Profile"],
    ["111b", "Imaging Responder"],
    ["111c", "Imaging Automatic Archive"],
    ["111d", "Imaging Referenced Objects"],
    ["111e", "Handsfree"],
    ["111f", "Handsfree Audio Gateway"],
    ["1120", "Direct Printing Refrence Objects Service"],
    ["1121", "Reflected UI"],
    ["1122", "Basic Printing"],
    ["1123", "Printing Status"],
    ["1124", "Human Interface Device Service"],
    ["1125", "Hardcopy Cable Replacement"],
    ["1126", "HCR Print"],
    ["1127", "HCR Scan"],
    ["1128", "Common ISDN Access"],
    ["112d", "SIM Access"],
    ["112e", "Phonebook Access Client"],
    ["112f", "Phonebook Access Server"],
    ["1130", "Phonebook Access"],
    ["1131", "Headset HS"],
    ["1132", "Message Access Server"],
    ["1133", "Message Notification Server"],
    ["1134", "Message Access Profile"],
    ["1135", "GNSS"],
    ["1136", "GNSS Server"],
    ["1137", "3D Display"],
    ["1138", "3D Glasses"],
    ["1139", "3D Synchronization"],
    ["113a", "MPS Profile"],
    ["113b", "MPS Service"],
    ["1200", "PnP Information"],
    ["1201", "Generic Networking"],
    ["1202", "Generic File Transfer"],
    ["1203", "Generic Audio"],
    ["1204", "Generic Telephony"],
    ["1205", "UPNP Service"],
    ["1206", "UPNP IP Service"],
    ["1300", "UPNP IP PAN"],
    ["1301", "UPNP IP LAP"],
    ["1302", "UPNP IP L2CAP"],
    ["1303", "Video Source"],
    ["1304", "Video Sink"],
    ["1305", "Video Distribution"],
    ["1400", "HDP"],
    ["1401", "HDP Source"],
    ["1402", "HDP Sink"],
    ["1800", "Generic Access Profile"],
    ["1801", "Generic Attribute Profile"],
    ["1802", "Immediate Alert"],
    ["1803", "Link Loss"],
    ["1804", "Tx Power"],
    ["1805", "Current Time Service"],
    ["1806", "Reference Time Update Service"],
    ["1807", "Next DST Change Service"],
    ["1808", "Glucose"],
    ["1809", "Health Thermometer"],
    ["180a", "Device Information"],
    ["180d", "Heart Rate"],
    ["180e", "Phone Alert Status Service"],
    ["180f", "Battery Service"],
    ["1810", "Blood Pressure"],
    ["1811", "Alert Notification Service"],
    ["1812", "Human Interface Device"],
    ["1813", "Scan Parameters"],
    ["1814", "Running Speed and Cadence"],
    ["1815", "Automation IO"],
    ["1816", "Cycling Speed and Cadence"],
    ["1818", "Cycling Power"],
    ["1819", "Location and Navigation"],
    ["181a", "Environmental Sensing"],
    ["181b", "Body Composition"],
    ["181c", "User Data"],
    ["181d", "Weight Scale"],
    ["181e", "Bond Management"],
    ["181f", "Continuous Glucose Monitoring"],
    ["1820", "Internet Protocol Support"],
    ["1821", "Indoor Positioning"],
    ["1822", "Pulse Oximeter"],
    ["1823", "HTTP Proxy"],
    ["1824", "Transport Discovery"],
    ["1825", "Object Transfer"],
    ["2800", "Primary Service"],
    ["2801", "Secondary Service"],
    ["2802", "Include"],
    ["2803", "Characteristic"],
    ["2900", "Characteristic Extended Properties"],
    ["2901", "Characteristic User Description"],
    ["2902", "Client Characteristic Configuration"],
    ["2903", "Server Characteristic Configuration"],
    ["2904", "Characteristic Format"],
    ["2905", "Characteristic Aggregate Formate"],
    ["2906", "Valid Range"],
    ["2907", "External Report Reference"],
    ["2908", "Report Reference"],
    ["2909", "Number of Digitals"],
    ["290a", "Value Trigger Setting"],
    ["290b", "Environmental Sensing Configuration"],
    ["290c", "Environmental Sensing Measurement"],
    ["290d", "Environmental Sensing Trigger Setting"],
    ["290e", "Time Trigger Setting"],
    ["2a00", "Device Name"],
    ["2a01", "Appearance"],
    ["2a02", "Peripheral Privacy Flag"],
    ["2a03", "Reconnection Address"],
    ["2a04", "Peripheral Preferred Connection Parameters"],
    ["2a05", "Service Changed"],
    ["2a06", "Alert Level"],
    ["2a07", "Tx Power Level"],
    ["2a08", "Date Time"],
    ["2a09", "Day of Week"],
    ["2a0a", "Day Date Time"],
    ["2a0c", "Exact Time 256"],
    ["2a0d", "DST Offset"],
    ["2a0e", "Time Zone"],
    ["2a0f", "Local Time Information"],
    ["2a11", "Time with DST"],
    ["2a12", "Time Accuracy"],
    ["2a13", "Time Source"],
    ["2a14", "Reference Time Information"],
    ["2a16", "Time Update Control Point"],
    ["2a17", "Time Update State"],
    ["2a18", "Glucose Measurement"],
    ["2a19", "Battery Level"],
    ["2a1c", "Temperature Measurement"],
    ["2a1d", "Temperature Type"],
    ["2a1e", "Intermediate Temperature"],
    ["2a21", "Measurement Interval"],
    ["2a22", "Boot Keyboard Input Report"],
    ["2a23", "System ID"],
    ["2a24", "Model Number String"],
    ["2a25", "Serial Number String"],
    ["2a26", "Firmware Revision String"],
    ["2a27", "Hardware Revision String"],
    ["2a28", "Software Revision String"],
    ["2a29", "Manufacturer Name String"],
    ["2a2a", "IEEE 11073-20601 Regulatory Cert. Data List"],
    ["2a2b", "Current Time"],
    ["2a2c", "Magnetic Declination"],
    ["2a31", "Scan Refresh"],
    ["2a32", "Boot Keyboard Output Report"],
    ["2a33", "Boot Mouse Input Report"],
    ["2a34", "Glucose Measurement Context"],
    ["2a35", "Blood Pressure Measurement"],
    ["2a36", "Intermediate Cuff Pressure"],
    ["2a37", "Heart Rate Measurement"],
    ["2a38", "Body Sensor Location"],
    ["2a39", "Heart Rate Control Point"],
    ["2a3f", "Alert Status"],
    ["2a40", "Ringer Control Point"],
    ["2a41", "Ringer Setting"],
    ["2a42", "Alert Category ID Bit Mask"],
    ["2a43", "Alert Category ID"],
    ["2a44", "Alert Notification Control Point"],
    ["2a45", "Unread Alert Status"],
    ["2a46", "New Alert"],
    ["2a47", "Supported New Alert Category"],
    ["2a48", "Supported Unread Alert Category"],
    ["2a49", "Blood Pressure Feature"],
    ["2a4a", "HID Information"],
    ["2a4b", "Report Map"],
    ["2a4c", "HID Control Point"],
    ["2a4d", "Report"],
    ["2a4e", "Protocol Mode"],
    ["2a4f", "Scan Interval Window"],
    ["2a50", "PnP ID"],
    ["2a51", "Glucose Feature"],
    ["2a52", "Record Access Control Point"],
    ["2a53", "RSC Measurement"],
    ["2a54", "RSC Feature"],
    ["2a55", "SC Control Point"],
    ["2a56", "Digital"],
    ["2a58", "Analog"],
    ["2a5a", "Aggregate"],
    ["2a5b", "CSC Measurement"],
    ["2a5c", "CSC Feature"],
    ["2a5d", "Sensor Location"],
    ["2a63", "Cycling Power Measurement"],
    ["2a64", "Cycling Power Vector"],
    ["2a65", "Cycling Power Feature"],
    ["2a66", "Cycling Power Control Point"],
    ["2a67", "Location and Speed"],
    ["2a68", "Navigation"],
    ["2a69", "Position Quality"],
    ["2a6a", "LN Feature"],
    ["2a6b", "LN Control Point"],
    ["2a6c", "Elevation"],
    ["2a6d", "Pressure"],
    ["2a6e", "Temperature"],
    ["2a6f", "Humidity"],
    ["2a70", "True Wind Speed"],
    ["2a71", "True Wind Direction"],
    ["2a72", "Apparent Wind Speed"],
    ["2a73", "Apparent Wind Direction"],
    ["2a74", "Gust Factor"],
    ["2a75", "Pollen Concentration"],
    ["2a76", "UV Index"],
    ["2a77", "Irradiance"],
    ["2a78", "Rainfall"],
    ["2a79", "Wind Chill"],
    ["2a7a", "Heat Index"],
    ["2a7b", "Dew Point"],
    ["2a7c", "Trend"],
    ["2a7d", "Descriptor Value Changed"],
    ["2a7e", "Aerobic Heart Rate Lower Limit"],
    ["2a7f", "Aerobic Threshold"],
    ["2a80", "Age"],
    ["2a81", "Anaerobic Heart Rate Lower Limit"],
    ["2a82", "Anaerobic Heart Rate Upper Limit"],
    ["2a83", "Anaerobic Threshold"],
    ["2a84", "Aerobic Heart Rate Upper Limit"],
    ["2a85", "Date of Birth"],
    ["2a86", "Date of Threshold Assessment"],
    ["2a87", "Email Address"],
    ["2a88", "Fat Burn Heart Rate Lower Limit"],
    ["2a89", "Fat Burn Heart Rate Upper Limit"],
    ["2a8a", "First Name"],
    ["2a8b", "Five Zone Heart Rate Limits"],
    ["2a8c", "Gender"],
    ["2a8d", "Heart Rate Max"],
    ["2a8e", "Height"],
    ["2a8f", "Hip Circumference"],
    ["2a90", "Last Name"],
    ["2a91", "Maximum Recommended Heart Rate"],
    ["2a92", "Resting Heart Rate"],
    ["2a93", "Sport Type for Aerobic/Anaerobic Thresholds"],
    ["2a94", "Three Zone Heart Rate Limits"],
    ["2a95", "Two Zone Heart Rate Limit"],
    ["2a96", "VO2 Max"],
    ["2a97", "Waist Circumference"],
    ["2a98", "Weight"],
    ["2a99", "Database Change Increment"],
    ["2a9a", "User Index"],
    ["2a9b", "Body Composition Feature"],
    ["2a9c", "Body Composition Measurement"],
    ["2a9d", "Weight Measurement"],
    ["2a9e", "Weight Scale Feature"],
    ["2a9f", "User Control Point"],
    ["2aa0", "Magnetic Flux Density - 2D"],
    ["2aa1", "Magnetic Flux Density - 3D"],
    ["2aa2", "Language"],
    ["2aa3", "Barometric Pressure Trend"],
    ["2aa4", "Bond Management Control Point"],
    ["2aa5", "Bond Management Feature"],
    ["2aa6", "Central Address Resolution"],
    ["2aa7", "CGM Measurement"],
    ["2aa8", "CGM Feature"],
    ["2aa9", "CGM Status"],
    ["2aaa", "CGM Session Start Time"],
    ["2aab", "CGM Session Run Time"],
    ["2aac", "CGM Specific Ops Control Point"],
    ["2aad", "Indoor Positioning Configuration"],
    ["2aae", "Latitude"],
    ["2aaf", "Longitude"],
    ["2ab0", "Local North Coordinate"],
    ["2ab1", "Local East Coordinate"],
    ["2ab2", "Floor Number"],
    ["2ab3", "Altitude"],
    ["2ab4", "Uncertainty"],
    ["2ab5", "Location Name"],
    ["2ab6", "URI"],
    ["2ab7", "HTTP Headers"],
    ["2ab8", "HTTP Status Code"],
    ["2ab9", "HTTP Entity Body"],
    ["2aba", "HTTP Control Point"],
    ["2abb", "HTTPS Security"],
    ["2abc", "TDS Control Point"],
    ["2abd", "OTS Feature"],
    ["2abe", "Object Name"],
    ["2abf", "Object Type"],
    ["2ac0", "Object Size"],
    ["2ac1", "Object First-Created"],
    ["2ac2", "Object Last-Modified"],
    ["2ac3", "Object ID"],
    ["2ac4", "Object Properties"],
    ["2ac5", "Object Action Control Point"],
    ["2ac6", "Object List Control Point"],
    ["2ac7", "Object List Filter"],
    ["2ac8", "Object Changed"],
    ["feff", "GN Netcom"],
    ["fefe", "GN ReSound A/S"],
    ["fefd", "Gimbal Inc."],
    ["fefc", "Gimbal Inc."],
    ["fefb", "Stollmann E+V GmbH"],
    ["fefa", "PayPal Inc."],
    ["fef9", "PayPal Inc."],
    ["fef8", "Aplix Corporation"],
    ["fef7", "Aplix Corporation"],
    ["fef6", "Wicentric Inc."],
    ["fef5", "Dialog Semiconductor GmbH"],
    ["fef4", "Google"],
    ["fef3", "Google"],
    ["fef2", "CSR"],
    ["fef1", "CSR"],
    ["fef0", "Intel"],
    ["feef", "Polar Electro Oy"],
    ["feee", "Polar Electro Oy"],
    ["feed", "Tile Inc."],
    ["feec", "Tile Inc."],
    ["feeb", "Swirl Networks Inc."],
    ["feea", "Swirl Networks Inc."],
    ["fee9", "Quintic Corp."],
    ["fee8", "Quintic Corp."],
    ["fee7", "Tencent Holdings Limited"],
    ["fee6", "Seed Labs Inc."],
    ["fee5", "Nordic Semiconductor ASA"],
    ["fee4", "Nordic Semiconductor ASA"],
    ["fee3", "Anki Inc."],
    ["fee2", "Anki Inc."],
    ["fee1", "Anhui Huami Information Technology Co."],
    ["fee0", "Anhui Huami Information Technology Co."],
    ["fedf", "Design SHIFT"],
    ["fede", "Coin Inc."],
    ["fedd", "Jawbone"],
    ["fedc", "Jawbone"],
    ["fedb", "Perka Inc."],
    ["feda", "ISSC Technologies Corporation"],
    ["fed9", "Pebble Technology Corporation"],
    ["fed8", "Google"],
    ["fed7", "Broadcom Corporation"],
    ["fed6", "Broadcom Corporation"],
    ["fed5", "Plantronics Inc."],
    ["fed4", "Apple Inc."],
    ["fed3", "Apple Inc."],
    ["fed2", "Apple Inc."],
    ["fed1", "Apple Inc."],
    ["fed0", "Apple Inc."],
    ["fecf", "Apple Inc."],
    ["fece", "Apple Inc."],
    ["fecd", "Apple Inc."],
    ["fecc", "Apple Inc."],
    ["fecb", "Apple Inc."],
    ["feca", "Apple Inc."],
    ["fec9", "Apple Inc."],
    ["fec8", "Apple Inc."],
    ["fec7", "Apple Inc."],
    ["fec6", "Kocomojo LLC"],
    ["fec5", "Realtek Semiconductor Corp."],
    ["fec4", "PLUS Location Systems"],
    ["fec3", "360fly Inc."],
    ["fec2", "Blue Spark Technologies Inc."],
    ["fec1", "KDDI Corporation"],
    ["fec0", "KDDI Corporation"],
    ["febf", "Nod Inc."],
    ["febe", "Bose Corporation"],
    ["febd", "Clover Network Inc."],
    ["febc", "Dexcom Inc."],
    ["febb", "adafruit industries"],
    ["feba", "Tencent Holdings Limited"],
    ["feb9", "LG Electronics"],
    ["feb8", "Facebook Inc."],
    ["feb7", "Facebook Inc."],
    ["feb6", "Vencer Co Ltd"],
    ["feb5", "WiSilica Inc."],
    ["feb4", "WiSilica Inc."],
    ["feb3", "Taobao"],
    ["feb2", "Microsoft Corporation"],
    ["feb1", "Electronics Tomorrow Limited"],
    ["feb0", "Nest Labs Inc."],
    ["feaf", "Nest Labs Inc."],
    ["feae", "Nokia Corporation"],
    ["fead", "Nokia Corporation"],
    ["feac", "Nokia Corporation"],
    ["feab", "Nokia Corporation"],
    ["feaa", "Google"],
    ["fea9", "Savant Systems LLC"],
    ["fea8", "Savant Systems LLC"],
    ["fea7", "UTC Fire and Security"],
    ["fea6", "GoPro Inc."],
    ["fea5", "GoPro Inc."],
    ["fea4", "Paxton Access Ltd"],
    ["fea3", "ITT Industries"],
    ["fea2", "Intrepid Control Systems Inc."],
    ["fea1", "Intrepid Control Systems Inc."],
    ["fea0", "Google"],
    ["fe9f", "Google"],
    ["fe9e", "Dialog Semiconductor B.V."],
    ["fe9d", "Mobiquity Networks Inc"],
    ["fe9c", "GSI Laboratories Inc."],
    ["fe9b", "Samsara Networks Inc"],
    ["fe9a", "Estimote"],
    ["fe99", "Currant Inc."],
    ["fe98", "Currant Inc."],
    ["fe97", "Tesla Motor Inc."],
    ["fe96", "Tesla Motor Inc."],
    ["fe95", "Xiaomi Inc."],
    ["fe94", "OttoQ Inc."],
    ["fe93", "OttoQ Inc."],
    ["fe92", "Jarden Safety & Security"],
    ["fe91", "Shanghai Imilab Technology Co.Ltd"],
    ["fe90", "JUMA"],
    ["fe8f", "CSR"],
    ["fe8e", "ARM Ltd"],
    ["fe8d", "Interaxon Inc."],
    ["fe8c", "TRON Forum"],
    ["fe8b", "Apple Inc."],
    ["fe8a", "Apple Inc."],
    ["fe89", "B&O Play A/S"],
    ["fe88", "SALTO SYSTEMS S.L."],
    ["fe87", "Qingdao Yeelink Information Technology Co. Ltd."],
    ["fe86", "HUAWEI Technologies Co. Ltd."],
    ["fe85", "RF Digital Corp"],
    ["fe84", "RF Digital Corp"],
    ["fe83", "Blue Bite"],
    ["fe82", "Medtronic Inc."],
    ["fe81", "Medtronic Inc."],
    ["fe80", "Doppler Lab"],
    ["fe7f", "Doppler Lab"],
    ["fe7e", "Awear Solutions Ltd"],
    ["fe7d", "Aterica Health Inc."],
    ["fe7c", "Stollmann E+V GmbH"],
    ["fe7b", "Orion Labs Inc."],
    ["fffe", "Alliance for Wireless Power (A4WP)"],
    ["fffd", "Fast IDentity Online Alliance (FIDO)"],
    ["FFE0", "Simple Keys Service"],
    ["FFE1", "Key press state"],
  ]
}

