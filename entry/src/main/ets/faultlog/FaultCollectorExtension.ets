import { FaultLogExtensionAbility, FaultLogExtensionContext } from '@kit.PerformanceAnalysisKit';
import { FaultLogCollector, FaultReport } from '../model/FaultLogCollector';

export default class FaultCollectorExtension extends FaultLogExtensionAbility {
  private reports: FaultReport[] = [];
  private sequence: number = 0;
  private connected: boolean = false;
  private lifecycleNote: string = 'FaultLog extension idle';

  onConnect(): void {
    const context = this.context as FaultLogExtensionContext;
    this.connected = true;
    this.lifecycleNote = FaultLogCollector.buildExtensionLifecycleNote('connected', context);
  }

  onDisconnect(): void {
    const context = this.context as FaultLogExtensionContext;
    this.connected = false;
    this.lifecycleNote = FaultLogCollector.buildExtensionLifecycleNote('disconnected', context);
  }

  onFaultReportReady(): void {
    this.sequence += 1;
    const network = this.connected ? 'Wi-Fi' : 'Cellular';
    const report = FaultLogCollector.captureFaultReportReady(this.sequence, network);
    this.reports = [report, ...this.reports];
    this.reports = FaultLogCollector.markForWifiUpload(this.reports);
    this.lifecycleNote = `Fault report ready: ${report.kind} queued`;
  }
}