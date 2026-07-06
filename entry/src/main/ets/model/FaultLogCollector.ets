import { FaultLogExtensionContext } from '@kit.PerformanceAnalysisKit';

export type FaultKind = 'Crash' | 'Freeze' | 'ANR';
export type QueueState = 'Queued' | 'Held for Wi-Fi' | 'Uploading' | 'Uploaded';

export class DeviceSnapshot {
  battery: number;
  memory: number;
  thermal: string;
  network: string;

  constructor(battery: number, memory: number, thermal: string, network: string) {
    this.battery = battery;
    this.memory = memory;
    this.thermal = thermal;
    this.network = network;
  }
}

export class FaultReport {
  id: number;
  kind: FaultKind;
  title: string;
  component: string;
  happenedAt: string;
  stackTop: string;
  deviceState: DeviceSnapshot;
  summary: string;
  queueState: QueueState;
  sizeKb: number;

  constructor(id: number, kind: FaultKind, title: string, component: string, happenedAt: string, stackTop: string,
    deviceState: DeviceSnapshot, summary: string, queueState: QueueState, sizeKb: number) {
    this.id = id;
    this.kind = kind;
    this.title = title;
    this.component = component;
    this.happenedAt = happenedAt;
    this.stackTop = stackTop;
    this.deviceState = deviceState;
    this.summary = summary;
    this.queueState = queueState;
    this.sizeKb = sizeKb;
  }
}

export class FaultLogCollector {
  static buildSeedReports(): FaultReport[] {
    return [
      FaultLogCollector.createReport(2401, 'Crash', 'Sensor pipeline null sample', 'WorkoutService',
        'SensorReader.ets:88', new DeviceSnapshot(44, 72, 'Warm', 'Cellular'), 'Held for Wi-Fi', 38),
      FaultLogCollector.createReport(2402, 'Freeze', 'Route renderer blocked main thread', 'MapTileRenderer',
        'MapTileRenderer.ets:142', new DeviceSnapshot(39, 81, 'Nominal', 'Cellular'), 'Held for Wi-Fi', 52),
      FaultLogCollector.createReport(2403, 'ANR', 'Uploader retry loop exceeded budget', 'TelemetryUploader',
        'UploadQueue.ets:63', new DeviceSnapshot(36, 67, 'Nominal', 'Offline'), 'Queued', 21)
    ];
  }

  static createReport(id: number, kind: FaultKind, title: string, component: string, stackTop: string,
    deviceState: DeviceSnapshot, queueState: QueueState, sizeKb: number): FaultReport {
    const summary = FaultLogCollector.buildHumanSummary(kind, title, component, stackTop, deviceState);
    return new FaultReport(id, kind, title, component, FaultLogCollector.timeLabel(), stackTop, deviceState, summary,
      queueState, sizeKb);
  }

  static buildHumanSummary(kind: FaultKind, title: string, component: string, stackTop: string,
    deviceState: DeviceSnapshot): string {
    return `${kind} in ${component}: ${title}. Top frame ${stackTop}. Battery ${deviceState.battery}%, memory ${deviceState.memory}%, ${deviceState.network}.`;
  }

  static captureFaultReportReady(sequence: number, network: string): FaultReport {
    const kind = FaultLogCollector.kindForSequence(sequence);
    const title = FaultLogCollector.titleForKind(kind);
    const component = FaultLogCollector.componentForKind(kind);
    const stackTop = FaultLogCollector.stackForKind(kind);
    const snapshot = new DeviceSnapshot(58 - sequence * 3, 61 + sequence * 5, sequence % 2 === 0 ? 'Nominal' : 'Warm',
      network);
    const queueState: QueueState = network === 'Wi-Fi' ? 'Queued' : 'Held for Wi-Fi';
    return FaultLogCollector.createReport(2500 + sequence, kind, title, component, stackTop, snapshot, queueState,
      24 + sequence * 7);
  }

  static markForWifiUpload(reports: FaultReport[]): FaultReport[] {
    return reports.map((report: FaultReport) => {
      if (report.queueState === 'Uploaded') {
        return report;
      }
      return FaultLogCollector.cloneWithState(report, 'Held for Wi-Fi');
    });
  }

  static uploadQueued(reports: FaultReport[]): FaultReport[] {
    return reports.map((report: FaultReport) => {
      if (report.queueState === 'Uploaded') {
        return report;
      }
      return FaultLogCollector.cloneWithState(report, 'Uploaded');
    });
  }

  static buildExtensionLifecycleNote(state: string, context: FaultLogExtensionContext): string {
    const extensionName = context.extensionAbilityInfo.name ? context.extensionAbilityInfo.name : 'FaultCollectorExtension';
    const moduleName = context.currentHapModuleInfo.name ? context.currentHapModuleInfo.name : 'entry';
    return `FaultLogExtensionContext ${state}: ${moduleName}/${extensionName}`;
  }

  static totalSize(reports: FaultReport[]): number {
    let total = 0;
    reports.forEach((report: FaultReport) => {
      if (report.queueState !== 'Uploaded') {
        total += report.sizeKb;
      }
    });
    return total;
  }

  static pendingCount(reports: FaultReport[]): number {
    return reports.filter((report: FaultReport) => report.queueState !== 'Uploaded').length;
  }

  static uploadedCount(reports: FaultReport[]): number {
    return reports.filter((report: FaultReport) => report.queueState === 'Uploaded').length;
  }

  static cloneWithState(report: FaultReport, queueState: QueueState): FaultReport {
    return new FaultReport(report.id, report.kind, report.title, report.component, report.happenedAt, report.stackTop,
      report.deviceState, report.summary, queueState, report.sizeKb);
  }

  static kindForSequence(sequence: number): FaultKind {
    const index = sequence % 3;
    if (index === 1) {
      return 'Freeze';
    }
    if (index === 2) {
      return 'ANR';
    }
    return 'Crash';
  }

  static titleForKind(kind: FaultKind): string {
    if (kind === 'Freeze') {
      return 'Complication refresh timed out';
    }
    if (kind === 'ANR') {
      return 'Background collector waited on network';
    }
    return 'Vitals cache invalid pointer';
  }

  static componentForKind(kind: FaultKind): string {
    if (kind === 'Freeze') {
      return 'ComplicationUpdater';
    }
    if (kind === 'ANR') {
      return 'FaultUploadScheduler';
    }
    return 'VitalsRepository';
  }

  static stackForKind(kind: FaultKind): string {
    if (kind === 'Freeze') {
      return 'ComplicationUpdater.ets:117';
    }
    if (kind === 'ANR') {
      return 'FaultUploadScheduler.ets:74';
    }
    return 'VitalsRepository.ets:52';
  }

  static timeLabel(): string {
    const date = new Date();
    const hours = date.getHours() < 10 ? `0${date.getHours()}` : `${date.getHours()}`;
    const minutes = date.getMinutes() < 10 ? `0${date.getMinutes()}` : `${date.getMinutes()}`;
    return `${hours}:${minutes}`;
  }
}