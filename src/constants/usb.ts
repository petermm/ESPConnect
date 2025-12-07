export const USB_VENDOR_NAMES: Record<number, string> = {
  0x303a: 'Espressif',
  0x1a86: 'WCH (CH34x)',
  0x10c4: 'Silicon Labs (CP210x)',
  0x0403: 'FTDI',
};

export const USB_PRODUCT_NAMES: Record<string, string> = {
  '1A86:55D3': 'CH343 Bridge',
  '1A86:7523': 'CH340 USB-Serial',
  '303A:1001': 'USB JTAG/Serial',
  '303A:4001': 'ESP32-S3 DevKit',
  '303A:4002': 'USB JTAG/Serial (CDC)',
  '10C4:EA60': 'CP210x USB-Serial',
  '0403:6001': 'FT232R USB UART',
};

export interface UsbBridgeInfo {
  name: string;
  maxBaudrate: number;
}

export interface UsbVendorInfo {
  vendorName: string;
  products: Record<number, UsbBridgeInfo>;
}

export const USB_BRIDGE_CAPABILITIES: Record<number, UsbVendorInfo> = {
  0x1a86: {
    vendorName: "QinHeng Electronics",
    products: {
      0x7522: { name: "CH340", maxBaudrate: 460_800 },
      0x7523: { name: "CH340", maxBaudrate: 460_800 },
      0x7584: { name: "CH340", maxBaudrate: 460_800 },
      0x5523: { name: "CH341", maxBaudrate: 2_000_000 },
      0x55d3: { name: "CH343", maxBaudrate: 6_000_000 },
      0x55d4: { name: "CH9102", maxBaudrate: 6_000_000 },
      0x55d8: { name: "CH9101", maxBaudrate: 3_000_000 },
    },
  },

  0x10c4: {
    vendorName: "Silicon Labs",
    products: {
      0xea60: { name: "CP2102(n)", maxBaudrate: 3_000_000 },
      0xea70: { name: "CP2105", maxBaudrate: 2_000_000 },
      0xea71: { name: "CP2108", maxBaudrate: 2_000_000 },
    },
  },

  0x0403: {
    vendorName: "FTDI",
    products: {
      0x6001: { name: "FT232R", maxBaudrate: 3_000_000 },
      0x6010: { name: "FT2232", maxBaudrate: 3_000_000 },
      0x6011: { name: "FT4232", maxBaudrate: 3_000_000 },
      0x6014: { name: "FT232H", maxBaudrate: 12_000_000 },
      0x6015: { name: "FT230X", maxBaudrate: 3_000_000 },
    },
  },

  0x303a: {
    vendorName: "Espressif Systems",
    products: {
      0x0002: { name: "ESP32-S2 Native USB", maxBaudrate: 2_000_000 },
      0x1001: { name: "ESP32 Native USB", maxBaudrate: 2_000_000 },
      0x1002: { name: "ESP32 Native USB", maxBaudrate: 2_000_000 },
      0x4002: { name: "ESP32 Native USB (CDC)", maxBaudrate: 2_000_000 },
      0x1000: { name: "ESP32 Native USB", maxBaudrate: 2_000_000 },
    },
  },
};

export function getUsbDeviceInfo(vid: number, pid: number) {
  const vendor = USB_BRIDGE_CAPABILITIES[vid];
  if (!vendor) return undefined;

  const product = vendor.products[pid];
  if (!product) return { vendorName: vendor.vendorName, product: undefined };

  return {
    vendorName: vendor.vendorName,
    productName: product.name,
    maxBaudrate: product.maxBaudrate,
  };
}

