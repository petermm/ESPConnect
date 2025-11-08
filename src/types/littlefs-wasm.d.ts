declare module '/wasm/littlefs/index.js' {
  export interface LittleFSFileEntry {
    path: string;
    size: number;
  }

  export interface LittleFS {
    format(): void;
    list(): LittleFSFileEntry[];
    addFile(path: string, data: Uint8Array | ArrayBuffer | string): void;
    deleteFile(path: string): void;
  }

  export interface LittleFSOptions {
    blockSize?: number;
    blockCount?: number;
    lookaheadSize?: number;
    wasmURL?: string | URL;
    formatOnInit?: boolean;
  }

  export function createLittleFS(options?: LittleFSOptions): Promise<LittleFS>;
  export default createLittleFS;
}
