import { FaultLogCollector, FaultReport, QueueState } from '../model/FaultLogCollector';

const QUEUE_DESTINATION: string = 'queue';

class QueueNavParam {
  pending: number;
  uploaded: number;

  constructor(pending: number, uploaded: number) {
    this.pending = pending;
    this.uploaded = uploaded;
  }
}

@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();

  @State networkIndex: number = 0;
  @State reports: FaultReport[] = FaultLogCollector.buildSeedReports();
  @State latestAction: string = 'FaultLog extension registered';
  @State lifecycleState: string = 'Waiting for callback';
  @State simulatedSequence: number = 3;

  networkLabel(): string {
    if (this.networkIndex === 1) {
      return 'Wi-Fi';
    }
    if (this.networkIndex === 2) {
      return 'Offline';
    }
    return 'Cellular';
  }

  simulateFaultReady(): void {
    this.simulatedSequence += 1;
    const report = FaultLogCollector.captureFaultReportReady(this.simulatedSequence, this.networkLabel());
    this.reports = [report, ...this.reports];
    if (this.networkLabel() !== 'Wi-Fi') {
      this.reports = FaultLogCollector.markForWifiUpload(this.reports);
      this.latestAction = `${report.kind} collected, upload held`;
    } else {
      this.latestAction = `${report.kind} collected for upload`;
    }
    this.lifecycleState = 'onFaultReportReady()';
  }

  reconnectWifi(): void {
    this.networkIndex = 1;
    this.reports = FaultLogCollector.uploadQueued(this.reports);
    this.latestAction = 'Wi-Fi reconnected, telemetry uploaded';
    this.lifecycleState = 'FaultLogExtensionContext active';
  }

  holdForWifi(): void {
    this.networkIndex = 0;
    this.reports = FaultLogCollector.markForWifiUpload(this.reports);
    this.latestAction = 'Cellular protected, batch held';
    this.lifecycleState = 'FaultLogExtensionContext background';
  }

  clearUploaded(): void {
    this.reports = this.reports.filter((report: FaultReport) => report.queueState !== 'Uploaded');
    this.latestAction = 'Uploaded reports cleared';
  }

  openQueue(): void {
    this.pathStack.pushPathByName(QUEUE_DESTINATION,new QueueNavParam(this.pendingCount(), this.uploadedCount()),true);
  }

  closeDestination(): void {
    this.pathStack.pop(true);
  }

  visibleReports(): FaultReport[] {
    return this.reports.slice(0, 3);
  }

  pendingCount(): number {
    return FaultLogCollector.pendingCount(this.reports);
  }

  uploadedCount(): number {
    return FaultLogCollector.uploadedCount(this.reports);
  }

  totalSize(): number {
    return FaultLogCollector.totalSize(this.reports);
  }

  progressWidth(): string {
    const total = this.pendingCount() + this.uploadedCount();
    if (total === 0) {
      return '8%';
    }
    const value = Math.max(8, Math.min(100, Math.round(this.pendingCount() * 100 / total)));
    return `${value}%`;
  }

  statusText(value: string, maxLength: number = 44): string {
    if (value.length <= maxLength) {
      return value;
    }
    return `${value.substring(0, maxLength - 1)}...`;
  }

  kindColor(kind: string): ResourceColor {
    if (kind === 'Crash') {
      return '#E8AAA3';
    }
    if (kind === 'Freeze') {
      return '#A8DADC';
    }
    return '#F1C27D';
  }

  stateColor(state: QueueState): ResourceColor {
    if (state === 'Uploaded') {
      return '#5B8E7D';
    }
    if (state === 'Uploading') {
      return '#5E8FAF';
    }
    if (state === 'Held for Wi-Fi') {
      return '#8A7442';
    }
    return '#66737C';
  }

  @Builder
  DestinationMap(name: string, param: Object): void {
    if (name === QUEUE_DESTINATION) {
      NavDestination() {
        this.QueuePage()
      }
      .hideTitleBar(true)
      .backgroundColor('#F6F2EA')
    }
  }

  @Builder
  DashboardPage(): void {
    Stack({ alignContent: Alignment.Center }) {
      Scroll() {
        Column({ space: 5 }) {
          this.TitleBand('FAULT DECK', this.networkLabel(), `${this.pendingCount()}`)

          this.QueueMeter()

          Row({ space: 5 }) {
            this.NetworkSelector()
            this.CommandDock()
          }
          .width('64%')
          .height(58)

          Column({ space: 5 }) {
            Text('Recent trace')
              .fontSize(8)
              .fontColor('#7A6F61')
              .maxLines(1)
              .width('100%')
            ForEach(this.visibleReports(), (report: FaultReport) => {
              this.TraceLine(report)
            }, (report: FaultReport) => `${report.id}`)
          }
          .width('68%')

          Row({ space: 5 }) {
            this.FooterAction('Queue', () => {
              this.openQueue();
            })
            this.FooterAction('Hold', () => {
              this.holdForWifi();
            })
          }
          .width('54%')
        }
        .width('100%')
        .padding({ top: 38, bottom: 34 })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F2EA')
  }

  @Builder
  QueuePage(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 5 }) {
        this.TitleBand('BATCH QUEUE', `${this.totalSize()} KB held`, `${this.reports.length}`)

        Row({ space: 5 }) {
          this.QueueMetric('Pending', `${this.pendingCount()}`)
          this.QueueMetric('Uploaded', `${this.uploadedCount()}`)
          this.QueueMetric('Policy', this.networkLabel())
        }
        .width('66%')
        .height(36)

        Column({ space: 4 }) {
          Row() {
            Text('TYPE')
              .fontSize(7)
              .fontColor('#7A6F61')
              .width('24%')
            Text('COMPONENT')
              .fontSize(7)
              .fontColor('#7A6F61')
              .layoutWeight(1)
            Text('STATE')
              .fontSize(7)
              .fontColor('#7A6F61')
              .width('30%')
              .textAlign(TextAlign.End)
          }
          .width('100%')

          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.reports, (report: FaultReport) => {
                this.BatchRow(report)
              }, (report: FaultReport) => `${report.id}`)
            }
            .width('100%')
          }
          .layoutWeight(1)
        }
        .width('68%')
        .layoutWeight(1)

        Row({ space: 5 }) {
          this.FooterAction('Back', () => {
            this.closeDestination();
          })
          this.FooterAction('Fault', () => {
            this.simulateFaultReady();
          })
          this.FooterAction('Wi-Fi', () => {
            this.reconnectWifi();
          })
          this.FooterAction('Clear', () => {
            this.clearUploaded();
          })
        }
        .width('66%')
      }
      .width('100%')
      .height('100%')
      .padding({ top: 38, bottom: 34 })
      .alignItems(HorizontalAlign.Center)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F2EA')
  }

  @Builder
  TitleBand(title: string, subtitle: string, badge: string): void {
    Row() {
      Column({ space: 0 }) {
        Text(title)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2F3437')
          .maxLines(1)
        Text(subtitle)
          .fontSize(7)
          .fontColor('#7A6F61')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(badge)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F3437')
        .width(28)
        .height(20)
        .backgroundColor('#E9DFA7')
        .borderRadius(4)
        .textAlign(TextAlign.Center)
    }
    .width('52%')
  }

  @Builder
  QueueMeter(): void {
    Column({ space: 5 }) {
      Row() {
        Column({ space: 0 }) {
          Text(`${this.pendingCount()}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2F3437')
            .maxLines(1)
          Text('pending')
            .fontSize(8)
            .fontColor('#7A6F61')
            .maxLines(1)
        }
        .width(58)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 3 }) {
          Text(this.statusText(this.lifecycleState, 32))
            .fontSize(8)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2F3437')
            .maxLines(1)
          Text(this.statusText(this.latestAction, 46))
            .fontSize(7)
            .fontColor('#6A7473')
            .maxLines(2)
          Text(`${this.totalSize()} KB buffered`)
            .fontSize(7)
            .fontColor('#5E8FAF')
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor('#E6E0D5')
          .borderRadius(3)
        Row()
          .width(this.progressWidth())
          .height(6)
          .backgroundColor('#B6CEC7')
          .borderRadius(3)
      }
      .width('100%')
      .height(6)
    }
    .width('68%')
    .height(86)
    .padding({ left: 9, right: 9, top: 8, bottom: 8 })
    .backgroundColor('#FFFDF8')
    .border({ width: 1, color: '#E2D8C9' })
    .borderRadius(8)
  }

  @Builder
  NetworkSelector(): void {
    Column({ space: 3 }) {
      this.NetworkTick('Cell', 0)
      this.NetworkTick('Wi-Fi', 1)
      this.NetworkTick('Off', 2)
    }
    .width(48)
    .height('100%')
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    .backgroundColor('#EFE7DA')
    .borderRadius(8)
  }

  @Builder
  NetworkTick(label: string, index: number): void {
    Text(label)
      .fontSize(8)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.networkIndex === index ? '#2F3437' : '#7A6F61')
      .height(13)
      .width('100%')
      .backgroundColor(this.networkIndex === index ? '#FFFDF8' : '#EFE7DA')
      .borderRadius(4)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.networkIndex = index;
      })
  }

  @Builder
  CommandDock(): void {
    Column({ space: 4 }) {
      Row({ space: 5 }) {
        this.CommandTile('Fault', 'collect', () => {
          this.simulateFaultReady();
        })
        this.CommandTile('Wi-Fi', 'flush', () => {
          this.reconnectWifi();
        })
      }
      .width('100%')
      .height(27)

      Row({ space: 5 }) {
        this.CommandTile('Queue', 'open', () => {
          this.openQueue();
        })
        this.CommandTile('Hold', 'cell save', () => {
          this.holdForWifi();
        })
      }
      .width('100%')
      .height(27)
    }
    .layoutWeight(1)
  }

  @Builder
  CommandTile(label: string, value: string, action: () => void): void {
    Column({ space: 0 }) {
      Text(label)
        .fontSize(7)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F3437')
        .maxLines(1)
      Text(value)
        .fontSize(7)
        .fontColor('#7A6F61')
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#D9E8E4')
    .borderRadius(6)
    .onClick(action)
  }

  @Builder
  TraceLine(report: FaultReport): void {
    Row({ space: 6 }) {
      Row()
        .width(5)
        .height(34)
        .backgroundColor(this.kindColor(report.kind))
        .borderRadius(3)

      Column({ space: 1 }) {
        Row() {
          Text(report.kind)
            .fontSize(8)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2F3437')
            .width(44)
            .maxLines(1)
          Text(report.component)
            .fontSize(9)
            .fontColor('#2F3437')
            .layoutWeight(1)
            .maxLines(1)
        }
        .width('100%')
        Text(this.statusText(report.stackTop, 42))
          .fontSize(8)
          .fontColor('#7A6F61')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(34)
    .padding({ left: 6, right: 6, top: 3, bottom: 3 })
    .backgroundColor('#FFFDF8')
    .borderRadius(6)
  }

  @Builder
  QueueMetric(label: string, value: string): void {
    Column({ space: 1 }) {
      Text(label)
        .fontSize(7)
        .fontColor('#7A6F61')
        .maxLines(1)
      Text(value)
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F3437')
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFDF8')
    .borderRadius(6)
    .border({ width: 1, color: '#E2D8C9' })
  }

  @Builder
  BatchRow(report: FaultReport): void {
    Row({ space: 5 }) {
      Text(report.kind)
        .fontSize(8)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F3437')
        .width('24%')
        .height(22)
        .backgroundColor(this.kindColor(report.kind))
        .borderRadius(4)
        .textAlign(TextAlign.Center)

      Column({ space: 0 }) {
        Text(report.component)
          .fontSize(8)
          .fontColor('#2F3437')
          .maxLines(1)
        Text(`${report.happenedAt} ${report.sizeKb} KB`)
          .fontSize(7)
          .fontColor('#7A6F61')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(report.queueState)
        .fontSize(7)
        .fontColor(this.stateColor(report.queueState))
        .width('30%')
        .maxLines(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(31)
    .padding({ left: 6, right: 6 })
    .backgroundColor('#FFFDF8')
    .borderRadius(6)
  }

  @Builder
  FooterAction(label: string, action: () => void): void {
    Text(label)
      .height(25)
      .layoutWeight(1)
      .fontSize(7)
      .fontWeight(FontWeight.Medium)
      .fontColor('#2F3437')
      .maxLines(1)
      .textAlign(TextAlign.Center)
      .backgroundColor('#C9DCD7')
      .borderRadius(6)
      .onClick(action)
  }

  build() {
    Navigation(this.pathStack) {
      this.DashboardPage()
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.DestinationMap)
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F2EA')
  }
}