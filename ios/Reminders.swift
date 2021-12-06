import EventKit;

@objc(Reminders)
class Reminders: NSObject {
    @objc static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    let eventStore = EKEventStore();
    
    @objc
    func requestPermission(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        eventStore.requestAccess(to: EKEntityType.reminder, completion: {
            granted, error in
            if(error != nil){
                let nsError:NSError = NSError(
                    domain: "domain",
                    code: 200,
                    userInfo: ["debugDescription": error.debugDescription, "localizedDescription": error?.localizedDescription ?? ""]
                );

                reject("ERROR", "Failed to request access", nsError);
            } else {
                resolve(granted);
            }
        });
    }
    
    func toDictionary(reminder: EKReminder) -> Dictionary<String, Any?> {
        let alarms = reminder.alarms?.map({[
                "timestamp": ($0.absoluteDate?.timeIntervalSince1970 ?? 0) * 1000
            ]});
        
        return [
            reminder
        ];
    }
    
    @objc
    func getReminders(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        let matching: NSPredicate = eventStore.predicateForReminders(in: nil);

        eventStore.fetchReminders(matching: matching, completion: {
            reminders in
            let dictionaries = reminders?.map({ self.toDictionary(reminder: $0) });

            resolve(dictionaries ?? []);
        });
    }
    
    @objc
    func addReminder(_ config: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        let reminder = EKReminder(eventStore: eventStore);
        reminder.priority = 2;
        reminder.notes = config["note"] as? String;
        reminder.title = config["title"] as? String;
        reminder.calendar = eventStore.defaultCalendarForNewReminders();
        var timestamp = config["timestamp"] as? Double;
        timestamp! /= 1000;
        reminder.addAlarm(EKAlarm(absoluteDate: Date(timeIntervalSince1970: timestamp!)));
        do {
            try eventStore.save(reminder, commit: true);
            resolve(toDictionary(reminder: reminder));
        } catch {
            reject("ERROR", error.localizedDescription, NSError(domain: "DOMAIN", code: 200, userInfo: nil));
        }
    }
    
    @objc
    func removeReminder(_ id: String, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        let matching = eventStore.predicateForReminders(in: nil)
        eventStore.fetchReminders(matching: matching) {
            foundReminders in
            
            if(foundReminders?.isEmpty ?? true) {
                resolve(false)
                return
            }
            
            let reminder = foundReminders?.first(where: { $0.calendarItemIdentifier == id })
            
            if(reminder === nil) {
                resolve(false)
                return;
            }
            
            do {
                try self.eventStore.remove(reminder!, commit: true)
                resolve(true)
            } catch {
                resolve(false)
            }
        }
    }
}
