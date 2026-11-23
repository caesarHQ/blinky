import AppKit
import Carbon
import Darwin

final class Panel:NSPanel { override var canBecomeKey:Bool {true} }
private let ink = NSColor(name:nil) { appearance in
    appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        ? NSColor(srgbRed:0.55,green:0.85,blue:0.78,alpha:1)
        : NSColor(srgbRed:0.10,green:0.39,blue:0.34,alpha:1)
}
final class ResultRow: NSTableRowView {
    override func drawSelection(in dirtyRect:NSRect) {
        ink.withAlphaComponent(0.09).setFill()
        NSBezierPath(roundedRect:bounds.insetBy(dx:2,dy:2),xRadius:9,yRadius:9).fill()
        ink.setFill()
        NSBezierPath(roundedRect:NSRect(x:3,y:bounds.midY-10,width:2,height:20),xRadius:1,yRadius:1).fill()
    }
    override var interiorBackgroundStyle:NSView.BackgroundStyle { .normal }
}
final class HoverThumbnail: NSImageView {
    var source: URL? { didSet { if oldValue != source { dismiss() } } }
    private static weak var active: HoverThumbnail?
    private static var pointerAtEdit: NSPoint?

    static func suppressForTyping() {
        pointerAtEdit = NSEvent.mouseLocation
        active?.dismiss()
    }

    private var tracking: NSTrackingArea?
    private var generation = 0
    private var popup: NSPanel?

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        super.updateTrackingAreas()
        let area = NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.mouseMoved,.activeInKeyWindow,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event:NSEvent) { beginHover() }
    override func mouseMoved(with event:NSEvent) { beginHover() }

    private func beginHover() {
        if let parked = Self.pointerAtEdit {
            let now = NSEvent.mouseLocation
            guard hypot(now.x-parked.x, now.y-parked.y) >= 5 else {return}
            Self.pointerAtEdit = nil
        }
        guard source != nil, Self.active !== self else {return}
        Self.active?.dismiss()
        Self.active = self
        let ticket = generation
        guard let source else {return}
        DispatchQueue.main.asyncAfter(deadline:.now()+0.35) { [weak self] in
            guard self?.generation == ticket else {return}
            DispatchQueue.global(qos:.userInitiated).async {
                guard let cg = thumbnail(source,1440) else {return}
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == ticket, let parent=self.window,
                          parent.isKeyWindow, let screen=parent.screen else {return}
                    let anchor=parent.convertToScreen(self.convert(self.bounds.intersection(self.visibleRect),to:nil))
                    guard anchor.contains(NSEvent.mouseLocation) else {return}
                    let frame=screen.visibleFrame.insetBy(dx:8,dy:8)
                    let right=frame.maxX-anchor.maxX-8, left=anchor.minX-frame.minX-8
                    let width=min(680,max(left,right)), height=min(540,frame.height)
                    guard width>40, height>40 else {return}
                    let factor=min((width-16)/CGFloat(cg.width),(height-16)/CGFloat(cg.height),1)
                    let size=NSSize(width:CGFloat(cg.width)*factor+16,height:CGFloat(cg.height)*factor+16)
                    let x=right>=size.width || right>=left ? anchor.maxX+8 : anchor.minX-size.width-8
                    let y=max(frame.minY,min(frame.maxY-size.height,anchor.midY-size.height/2))
                    let box=NSPanel(contentRect:NSRect(origin:NSPoint(x:x,y:y),size:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                    box.isOpaque=false
                    box.backgroundColor = .clear
                    box.ignoresMouseEvents=true
                    box.hasShadow=true
                    let background=NSVisualEffectView(frame:NSRect(origin:.zero,size:size))
                    background.material = .popover
                    background.wantsLayer=true
                    background.layer?.cornerRadius=10
                    background.layer?.masksToBounds=true
                    let image=NSImageView(frame:background.bounds.insetBy(dx:8,dy:8))
                    image.image=NSImage(cgImage:cg,size:.zero)
                    image.imageScaling = .scaleProportionallyUpOrDown
                    background.addSubview(image)
                    box.contentView=background
                    self.popup=box
                    parent.addChildWindow(box,ordered:.above)
                    box.orderFront(nil)
                }
            }
        }
    }
    override func mouseExited(with event:NSEvent) {dismiss()}
    override func viewWillMove(toWindow newWindow:NSWindow?) {dismiss();super.viewWillMove(toWindow:newWindow)}
    private func dismiss() {
        if Self.active === self {Self.active = nil}
        generation += 1
        guard let popup else {return}
        popup.parent?.removeChildWindow(popup)
        popup.orderOut(nil)
        self.popup=nil
    }
}
final class ResultCell: NSTableCellView {
    let preview = HoverThumbnail()
    let title = NSTextField(labelWithString:"")
    let summary = NSTextField(wrappingLabelWithString:"")
    let date = NSTextField(labelWithString:"")
    let tags = NSTextField(labelWithString:"")
    var previewKey = ""

    init() {
        super.init(frame:.zero)
        date.font = .monospacedDigitSystemFont(ofSize:11,weight:.regular)
        date.textColor = .secondaryLabelColor
        date.alignment = .right
        preview.imageScaling = .scaleProportionallyUpOrDown
        title.font = .systemFont(ofSize:15,weight:.semibold)
        summary.font = .systemFont(ofSize:13)
        summary.textColor = .secondaryLabelColor
        summary.maximumNumberOfLines = 2
        tags.font = .systemFont(ofSize:11,weight:.medium)
        tags.textColor = ink
        for field in [title,tags] {field.lineBreakMode = .byTruncatingTail}
        for view in [preview,title,summary,tags,date] {addSubview(view)}
    }
    required init?(coder:NSCoder) {fatalError("Use init()")}
    override func layout() {
        super.layout()
        let w=max(0,bounds.width-220)
        preview.frame=NSRect(x:14,y:12,width:180,height:bounds.height-24)
        title.frame=NSRect(x:206,y:isFlipped ? 40 : bounds.height-60,width:max(0,w-116),height:20)
        date.frame=NSRect(x:bounds.width-122,y:isFlipped ? 42 : bounds.height-58,width:108,height:16)
        summary.frame=NSRect(x:206,y:isFlipped ? 64 : bounds.height-100,width:w,height:36)
        tags.frame=NSRect(x:206,y:isFlipped ? 106 : bounds.height-122,width:w,height:16)
    }
    func configure(url:URL,metadata:String,stamp:String) {
        preview.source = url
        let stem = url.deletingPathExtension().lastPathComponent
        let topic = stem.replacingOccurrences(of:#"(?i)(?:_| - | at )\d{4}-\d{2}-\d{2}[_ ](?:at )?\d{2}[-.]\d{2}[-.]\d{2}(?: \(\d+\))?$"#,with:"",options:.regularExpression).replacingOccurrences(of:"_",with:" ")
        title.stringValue = topic.prefix(1).uppercased()+topic.dropFirst()
        if let seconds=Double(stamp.split(separator:"/").first ?? "") {
            let value=Date(timeIntervalSince1970:seconds)
            date.stringValue=DateFormatter.localizedString(from:value,dateStyle:Calendar.current.isDateInToday(value) ? .none : .short,timeStyle:.short)
        } else {date.stringValue=""}
        let parts=metadata.components(separatedBy:"  ·  ")
        let labeled=metadata.hasPrefix("#") && parts.count>=2
        summary.stringValue=labeled ? parts[1] : metadata
        tags.stringValue=labeled ? parts[0].split(separator:" ").prefix(4).joined(separator:"   ") : ""
    }
}
final class App:NSObject,NSApplicationDelegate,NSTableViewDataSource,NSTableViewDelegate,NSSearchFieldDelegate {
    let index:Index
    init(index:Index){self.index=index}
    let panel=Panel(contentRect:NSRect(x:0,y:0,width:820,height:560),styleMask:[.titled,.closable,.fullSizeContentView,.utilityWindow],backing:.buffered,defer:false)
    let search=NSSearchField(), table=NSTableView(), status=NSTextField(labelWithString:""), scroll=NSScrollView()
    var item:NSStatusItem!, hot:EventHotKeyRef?, watch:DispatchSourceFileSystemObject?
    var copied=Set<String>(), copySince=Date()
    var rows=[[String]](), busy=false, captionBusy=false, lastScan=Date.distantPast, lastCaption=Date.distantPast, note="", hotWarning=""
    var pendingSearch: DispatchWorkItem?
    private let previews = OperationQueue()
    let cache=NSCache<NSString,NSImage>()
    var folder:String {prefs.string(forKey:"folder") ?? ""}
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        item.button?.image=NSImage(systemSymbolName:"photo.on.rectangle",accessibilityDescription:"Blink")
        let menu=NSMenu()
        for (title,action) in [("Search screenshots",#selector(show)),("Choose screenshot folder…",#selector(choose)),("Index clipboard image",#selector(paste)),("Quit Blink",#selector(quit))] {
            let entry=menu.addItem(withTitle:title,action:action,keyEquivalent:"");entry.target=self
        }
        let rename = NSMenuItem(title:"Auto-rename new screenshots",action:#selector(toggleRename(_:)),keyEquivalent:"")
        rename.target=self
        rename.state=prefs.object(forKey:"autoRename") as? Bool == false ? .off : .on
        menu.insertItem(rename,at:2)
        let copy = NSMenuItem(title:"Copy new screenshots to clipboard",action:#selector(toggleCopy(_:)),keyEquivalent:"")
        copy.target=self
        copy.state=prefs.bool(forKey:"copyToClipboard") ? .on : .off
        menu.insertItem(copy,at:3)
        item.menu=menu
        panel.acceptsMouseMovedEvents = true
        panel.title="Blink";panel.titlebarAppearsTransparent=true;panel.isFloatingPanel=true;panel.hidesOnDeactivate=true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        for control in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] {panel.standardWindowButton(control)?.isHidden=true}
        panel.collectionBehavior=[.moveToActiveSpace,.fullScreenAuxiliary]
        previews.maxConcurrentOperationCount = 2
        previews.qualityOfService = .utility
        search.controlSize = .large
        (search.cell as? NSSearchFieldCell)?.searchButtonCell=nil
        search.isBezeled=false
        search.drawsBackground=false
        search.focusRingType = .none
        search.placeholderString="Search screenshots…"
        search.font = .systemFont(ofSize:23,weight:.regular)
        search.delegate=self
        table.style = .plain
        table.backgroundColor = .clear
        scroll.drawsBackground=false
        scroll.autohidesScrollers=true
        table.addTableColumn(NSTableColumn(identifier:.init("result")));table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle;table.headerView=nil;table.rowHeight=176;table.delegate=self;table.dataSource=self;table.target=self;table.doubleAction=#selector(openResult)
        scroll.documentView=table;scroll.hasVerticalScroller=true
        status.font = .systemFont(ofSize:11);status.textColor = .secondaryLabelColor
        let button=NSButton(image:NSImage(systemSymbolName:"folder",accessibilityDescription:"Choose screenshot folder")!,target:self,action:#selector(choose))
        button.isBordered=false
        button.toolTip="Choose screenshot folder"
        let shortcuts=NSTextField(labelWithString:"↑↓  Select     ↩  Open     ⌘C  Copy")
        shortcuts.font = .systemFont(ofSize:11)
        shortcuts.textColor = .secondaryLabelColor
        let footer=NSStackView(views:[status,NSView(),shortcuts,button])
        let root = panel.contentView!
        for view in [search, scroll, footer] {
            root.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:view === search ? 53 : 18),
                view.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-18)
            ])
        }
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo:root.topAnchor,constant:14),
            search.heightAnchor.constraint(equalToConstant:48),
            scroll.topAnchor.constraint(equalTo:search.bottomAnchor,constant:12),
            scroll.bottomAnchor.constraint(equalTo:footer.topAnchor,constant:-8),
            footer.heightAnchor.constraint(equalToConstant:28),
            footer.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-12)
        ])
        let lens = NSImageView(image:NSImage(systemSymbolName:"magnifyingglass",accessibilityDescription:nil)!)
        lens.contentTintColor = ink
        root.addSubview(lens)
        lens.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([lens.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:23),
                                     lens.topAnchor.constraint(equalTo:search.topAnchor,constant:4),
                                     lens.widthAnchor.constraint(equalToConstant:21),
                                     lens.heightAnchor.constraint(equalToConstant:21)])
        for (anchor,offset) in [(scroll.topAnchor,CGFloat(-5)),(footer.topAnchor,CGFloat(-4))] {
            let rule=NSBox()
            rule.boxType = .separator
            root.addSubview(rule)
            rule.translatesAutoresizingMaskIntoConstraints=false
            NSLayoutConstraint.activate([rule.leadingAnchor.constraint(equalTo:root.leadingAnchor),rule.trailingAnchor.constraint(equalTo:root.trailingAnchor),rule.topAnchor.constraint(equalTo:anchor,constant:offset)])
        }
        panel.center()
        var spec=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),{_,_,pointer in
            Unmanaged<App>.fromOpaque(pointer!).takeUnretainedValue().show();return noErr
        },1,&spec,Unmanaged.passUnretained(self).toOpaque(),nil)
        if RegisterEventHotKey(UInt32(kVK_Space),UInt32(controlKey),EventHotKeyID(signature:0x534E4150,id:1),GetApplicationEventTarget(),0,&hot) != noErr {hotWarning="Shortcut busy · "}
        NSEvent.addLocalMonitorForEvents(matching:.keyDown){[weak self] event in
            guard let self,self.panel.isKeyWindow else {return event}
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "a",
               let editor = self.search.currentEditor(), self.panel.firstResponder === editor {
                editor.selectAll(nil)
                return nil
            }
            if [36,125,126,8].contains(event.keyCode), self.pendingSearch != nil {
                self.flushSearch()
            }
            switch event.keyCode {
            case 53:self.panel.orderOut(nil)
            case 36:self.openResult()
            case 125,126:
                if !self.rows.isEmpty {let n=min(max(0,self.table.selectedRow+(event.keyCode==125 ? 1 : -1)),self.rows.count-1);self.table.selectRowIndexes(IndexSet(integer:n),byExtendingSelection:false);self.table.scrollRowToVisible(n)}
            case 8 where event.modifierFlags.contains(.command):
                if let editor=self.search.currentEditor(),editor.selectedRange.length>0 {return event}
                if let url=self.selected(),let image=NSImage(contentsOf:url){NSPasteboard.general.clearContents();NSPasteboard.general.writeObjects([image]);self.panel.orderOut(nil)}
            default:return event
            };return nil
        }
        startWatch();show()
        Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in self?.tick()}
    }
    @objc func toggleRename(_ sender:NSMenuItem) {
        let enabled = sender.state != .on
        prefs.set(enabled,forKey:"autoRename")
        if enabled { prefs.set(Date(),forKey:"renameSince."+folder) }
        sender.state = enabled ? .on : .off
    }
    @objc func toggleCopy(_ sender:NSMenuItem) {
        let enabled = sender.state != .on
        prefs.set(enabled,forKey:"copyToClipboard")
        if enabled { copySince=Date() }
        sender.state = enabled ? .on : .off
    }
    // Put each newly saved screenshot on the clipboard, so a capture is both saved and ready to paste.
    func copyNewCaptures(attempt:Int=0){
        guard prefs.bool(forKey:"copyToClipboard"), !folder.isEmpty,
              let urls=try? FileManager.default.contentsOfDirectory(at:URL(fileURLWithPath:folder),includingPropertiesForKeys:[.creationDateKey],options:.skipsHiddenFiles) else {return}
        let cutoff=max(copySince,Date().addingTimeInterval(-20))
        let fresh=urls.compactMap { url -> (URL,Date)? in
            guard formats.contains(url.pathExtension.lowercased()), !copied.contains(url.path),
                  url.lastPathComponent.range(of:#"^(CleanShot|Screen ?Shot|Screen Capture)[ _-]+[0-9]{4}[-.][0-9]{2}"#,options:[.regularExpression,.caseInsensitive]) != nil,
                  let created=(try? url.resourceValues(forKeys:[.creationDateKey]))?.creationDate, created >= cutoff else {return nil}
            return (url,created)
        }.sorted { $0.1 < $1.1 }
        guard let newest=fresh.last?.0 else {return}
        guard let image=NSImage(contentsOf:newest), image.isValid else {
            // The file can appear before it is fully written; try again shortly.
            if attempt < 10 { DispatchQueue.main.asyncAfter(deadline:.now()+0.3){[weak self] in self?.copyNewCaptures(attempt:attempt+1)} }
            return
        }
        for (url,_) in fresh {copied.insert(url.path)}
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    @objc func quit(){NSApp.terminate(nil)}
    @objc func show(){NSApp.activate(ignoringOtherApps:true);panel.makeKeyAndOrderFront(nil);panel.makeFirstResponder(search);refresh()}
    @objc func choose(){
        let picker=NSOpenPanel();picker.canChooseFiles=false;picker.canChooseDirectories=true;picker.canCreateDirectories=true;picker.prompt="Watch folder"
        if picker.runModal() == .OK,let url=picker.url {prefs.set(url.path,forKey:"folder");startWatch();show()}
    }
    func startWatch(){
        watch?.cancel();watch=nil;lastScan = .distantPast;lastCaption = .distantPast;note=""
        guard !folder.isEmpty else {return}
        if prefs.object(forKey:"renameSince."+folder) == nil {prefs.set(Date(),forKey:"renameSince."+folder)}
        let fd=open(folder,O_EVTONLY)
        if fd >= 0 {let source=DispatchSource.makeFileSystemObjectSource(fileDescriptor:fd,eventMask:[.write,.rename,.delete],queue:.main)
            source.setEventHandler{[weak self] in self?.lastScan = .distantPast;self?.copyNewCaptures()};source.setCancelHandler{close(fd)};source.resume();watch=source}
        tick()
    }
    func tick(){
        let path=folder
        guard !path.isEmpty else {return}
        copyNewCaptures()
        if !busy {
            busy=true
            let scan=Date().timeIntervalSince(lastScan)>15
            if scan {lastScan=Date()}
            DispatchQueue.global(qos:.utility).async {
                if scan {self.index.scan(path)}
                self.index.recognize(path)
                self.index.indexNames(path)
                DispatchQueue.main.async{self.busy=false;if self.panel.isVisible {self.refresh()}}
            }
        }
        if !captionBusy,Date().timeIntervalSince(lastCaption)>5 {
            captionBusy=true;lastCaption=Date()
            Task { @MainActor in
                let message = await captions(index,folder:path)
                self.captionBusy = false
                if self.folder == path {self.note=message;self.refresh()}
            }
        }
    }
    @objc func paste(){
        guard !folder.isEmpty else {choose();return}
        guard let image=NSImage(pasteboard:.general),let tiff=image.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]) else {NSSound.beep();return}
        do {try png.write(to:URL(fileURLWithPath:folder).appendingPathComponent("Clipboard-"+UUID().uuidString+".png"),options:.atomic);lastScan = .distantPast;tick();show()} catch {NSApp.presentError(error)}
    }
    func controlTextDidChange(_ obj:Notification) {
        HoverThumbnail.suppressForTyping()
        pendingSearch?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushSearch() }
        pendingSearch = work
        DispatchQueue.main.asyncAfter(deadline:.now()+0.13,execute:work)
    }
    func flushSearch() {
        pendingSearch?.cancel()
        pendingSearch=nil
        refresh(reset:true)
    }
    func refresh(reset:Bool=false){
        guard pendingSearch == nil, panel.isVisible else {return}
        let prior=reset ? nil:selected()?.path
        let next=index.search(search.stringValue,folder:folder)
        if next != rows {
            let samePaths = next.map { $0[0] } == rows.map { $0[0] }
            let changed = samePaths ? IndexSet(next.indices.filter { next[$0] != rows[$0] }) : IndexSet()
            rows=next
            if samePaths {table.reloadData(forRowIndexes:changed,columnIndexes:IndexSet(integer:0))}
            else {table.reloadData()}
        if !rows.isEmpty {let n=rows.firstIndex(where:{$0[0]==prior}) ?? 0;table.selectRowIndexes(IndexSet(integer:n),byExtendingSelection:false)}
        }
        let activity = ["Index up to date","Visual description indexed",""].contains(note) ? "" : note
        let message=hotWarning+(folder.isEmpty ? "Choose the folder where your Mac saves screenshots" : activity)
        if status.stringValue != message {status.stringValue=message}
    }
    func selected()->URL? {rows.indices.contains(table.selectedRow) ? URL(fileURLWithPath:rows[table.selectedRow][0]):nil}
    @objc func openResult(){if let url=selected(){NSWorkspace.shared.open(url);panel.orderOut(nil)}}
    func tableView(_ tableView:NSTableView,rowViewForRow row:Int)->NSTableRowView? { ResultRow() }
    func numberOfRows(in tableView:NSTableView)->Int {rows.count}
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView? {
        let rowData=rows[row],url=URL(fileURLWithPath:rowData[0])
        let id = NSUserInterfaceItemIdentifier("ScreenshotResult")
        let cell = (table.makeView(withIdentifier:id,owner:nil) as? ResultCell) ?? ResultCell()
        cell.identifier = id
        let stamp = rowData.count > 2 ? rowData[2] : ""
        cell.configure(url:url,metadata:rowData[1],stamp:stamp)
        let key = url.path + stamp
        cell.previewKey = key
        if let image = cache.object(forKey:key as NSString) {
            cell.preview.image = image
        } else {
            cell.preview.image = nil
            previews.addOperation { [weak self, weak cell] in
                guard let cg = thumbnail(url,480) else {return}
                DispatchQueue.main.async {
                    let image = NSImage(cgImage:cg,size:.zero)
                    self?.cache.countLimit=120
                    self?.cache.setObject(image,forKey:key as NSString)
                    if cell?.previewKey == key {cell?.preview.image=image}
                }
            }
        }
        return cell
    }
}
do {
    let index=try Index(support)
    let app=App(index:index);NSApplication.shared.delegate=app;NSApplication.shared.run()
} catch {NSApplication.shared.presentError(error)}
