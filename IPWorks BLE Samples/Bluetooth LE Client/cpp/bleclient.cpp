/*
 * IPWorks BLE 2022 C++ Edition - Sample Project
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
 */

/*
 *  VS2017 is required to make use of the Windows 10 SDK.
 *
 *  BLEClient also requires that the following options be set in a project. These have already been set in this demo project.
 *
 *  a) C/C++  -  General  -  Consume Windows Runtime Extension  -   Yes(/ZW)
 *  b) C/C++  -  General  -  Additional #using Directories  -  "$(WindowsSdkDir_10)\UnionMetadata\10.0.15063.0;$(VSAPPIDDIR)\VC\vcpackages"
 *  c) C/C++  -  Code Generation  -  Enable Minimal Rebuild  -  No (/GM-)
 *
 *  Further, a threading model must be specified for the entry point, typically the "main" method. Here are a few examples:
 *
 *  [Platform::MTAThread]
 *  int main(int argc, char* argv[])
 *    ...
 *  [Platform::STAThread]
 *  int main(int argc, char* argv[])
 *    ...
 *  int main(Platform::Array<Platform::String^>^ args)
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "../../include/ipworksble.h"

#define LINE_LEN 80
#define CHAR_FLAG_BROADCAST         0x00000001
#define CHAR_FLAG_READ              0x00000002
#define CHAR_FLAG_WRITE_NO_RESPONSE 0x00000004
#define CHAR_FLAG_WRITE             0x00000008
#define CHAR_FLAG_NOTIFY            0x00000010
#define CHAR_FLAG_INDICATE          0x00000020
#define CHAR_FLAG_AUTH_SIGNED_WRITE 0x00000040
#define CHAR_FLAG_RELIABLE_WRITE    0x00000080
#define CHAR_FLAG_WRITEABLE_AUX     0x00000100

class MyBLEClient : public BLEClient {

public:
  virtual int FireAdvertisement(BLEClientAdvertisementEventParams *e) {
    printf("ServerId: %s Name: %s RSSI: %d TxPower: %d\n", e->ServerId, e->Name, e->RSSI, e->TxPower);
    return 0;
  }

  virtual int FireConnected(BLEClientConnectedEventParams *e) {
    if (!e->StatusCode) {
      printf("Connecting went OK\r\n");
    }
    return 0;
  }

  virtual int FireDisconnected(BLEClientDisconnectedEventParams *e) {
    if (!e->StatusCode) {
      printf("Disconnecting went OK\r\n");
    }
    return 0;
  }

  virtual int FireDiscovered(BLEClientDiscoveredEventParams *e) {
    if (e->GattType == 0) { // Service
      printf("ServiceId: %s | Uuid: %s | Description: %s\r\n", e->ServiceId, e->Uuid, e->Description);
    }
    else if (e->GattType == 1) { // Characteristic
      printf("\tCharacteristicId: %s | Uuid: %s | Description: %s\r\n", e->CharacteristicId, e->Uuid, e->Description);
    }
    else if (e->GattType == 2) { // Descriptor
      printf("\t\tDescriptorId: %s | Uuid: %s | Description: %s\r\n", e->DescriptorId, e->Uuid, e->Description);
    }
    return 0;
  }

  virtual int FireError(BLEClientErrorEventParams *e) {
    printf("An error was had! Code: %i Description: %s\r\n", e->ErrorCode, e->Description);
    return 0;
  }

  virtual int FireSubscribed(BLEClientSubscribedEventParams *e) {
    printf("Subscribed to %s -> %s. Description: %s\r\n", e->ServiceId, e->CharacteristicId, e->Description);
    return 0;

  }
};

void PrintValue(char* value, int format) {
  // This method helps display some of the common value formats, though not every possibility is accounted for.
  // As types like int and char can be system-dependent, this formatting may not work for every system.
  switch (format) {
  case 4:
    printf("Format: VF_UINT_8 | Value: %hhu\r\n", *(uint8*)(value));
    break;
  case 6:
    printf("Format: VF_UINT_16 | Value: %hhu\r\n", *(uint16*)(value));
    break;
  default:
    printf("Format Undefined. Interpretting as string. | Value: %s\r\n", value);
    break;
  }
}

// Pass the collection of flags and the flag you'd like to see if it has.
bool HasFlag(int flags, int flag) {
  return (flags & flag) == flag;
}

[Platform::MTAThread]
int main(int argc, char* argv[]) {
  // Declare/Initialize
  int ret_code = 0;
  MyBLEClient bleclient;

  char command[LINE_LEN];
  char serviceId[LINE_LEN];
  char *charId;
  int charIndex = 0;

  unsigned long endCount = GetTickCount() + 2 * 1000;

  // Welcome to the demo
  printf("Welcome to the BLEClient C++ Demo Application.\r\n");

  // Start scanning for devices (and check to see if BLE is supported)
  bleclient.SetActiveScanning(true);
  bleclient.StartScanning("");
  if (bleclient.GetLastErrorCode() != 0) {
    printf("%s\r\n", bleclient.GetLastError());
    goto endofprogram;
  }

  printf("Starting to scan.\r\n");
  // Scan for ~2 seconds
  while (GetTickCount() < endCount) {
    bleclient.DoEvents();
  }
  bleclient.StopScanning();
  printf("Scanning finished.\r\n");

  // Connect to a device
  printf("Enter the ServerId of the device you wish to connect to: ");
  fgets(command, LINE_LEN, stdin);
  command[strlen(command) - 1] = '\0';
  bleclient.Connect(command);
  if (bleclient.GetLastErrorCode() != 0) {
    printf("%s\r\n", bleclient.GetLastError());
    goto endofprogram;
  }

  // Discover all services
  printf("Discovering services for this device."); // ... for this server?
  bleclient.DiscoverServices("", "");
  if (bleclient.GetLastErrorCode() != 0) {
    printf("%s\r\n", bleclient.GetLastError());
    goto endofprogram;
  }

  // Discover characteristics for the selected service
  printf("Enter a ServiceId to discover characteristics: ");
  fgets(command, LINE_LEN, stdin);
  command[strlen(command) - 1] = '\0';
  strcpy_s(serviceId, command);
  bleclient.DiscoverCharacteristics(serviceId, "");
  if (bleclient.GetLastErrorCode() != 0) {
    printf("%s\r\n", bleclient.GetLastError());
    goto endofprogram;
  }

  // Get information about the selected characteristic
  printf("Select a Characteristic for more information (0...n): ");
  fgets(command, LINE_LEN, stdin);
  command[strlen(command) - 1] = '\0';
  charIndex = atoi(command);
  charId = bleclient.GetCharacteristicId(charIndex);
  if (bleclient.GetLastErrorCode() != 0) {
    printf("%s\r\n", bleclient.GetLastError());
    goto endofprogram;
  }

  // Display information about the selected characteristic
  printf("Characteristic Information:\r\n");
  printf("ServiceId: %s\r\n", serviceId);
  int flags = bleclient.GetCharacteristicFlags(charIndex); // Get flags to know what we can do with the characteristic.
  if (HasFlag(flags, CHAR_FLAG_READ)) {
    char * value;
    int * lenValue = 0;
    value = bleclient.ReadValue(serviceId, charId, "", lenValue);
    PrintValue(value, bleclient.GetCharacteristicValueFormat(charIndex));
  }
  else {
    printf("This characteristic's value cannot be read!");
  }
  if (bleclient.GetLastErrorCode() != 0) {
    printf("%s\r\n", bleclient.GetLastError());
    goto endofprogram;
  }

  // Decide to subscribe or not
  if (bleclient.GetCharacteristicCanSubscribe(charIndex)) {
    printf("Subscribe to characteristic? [Y/n]: ");
    fgets(command, LINE_LEN, stdin);
    command[strlen(command) - 1] = '\0';

    if (command[0] == 'Y' || command[0] == 'y') {
      bleclient.Subscribe(serviceId, charId);
    }
  }

endofprogram:
  printf("Enter any key to disconnect and exit.\r\n");
  getchar();
  bleclient.Disconnect();
  return ret_code;
}
 
 

