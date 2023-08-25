
import Foundation
import HealthKit
import UIKit

class DataSend{
  
  static let healthStore = HKHealthStore()
  var json:[String : Any] = [:]
  var targets = MasterViewController.targets
  var sleep:[String] = []
  
  
  /******  Runs Query for specificed identifier given   ******/
  public func runquery(count:Int, date:String, identity:String){
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd"
    let endTime = formatter.date(from: date)!
     
    let daysAgo = NSCalendar.current.date(byAdding: .day, value: -1, to: endTime)
    let pred = HKQuery.predicateForSamples(withStart: daysAgo, end: endTime, options: [])
    
    
    
    //RECURSIVE FUNCTION --> handles data
    if(count == targets.count){ // exit recursive functon
      do {
        let userAgeSexAndBloodType = try ProfileDataStore.getAgeSexAndBloodType()
        json["age"] = "\(userAgeSexAndBloodType.age)"
        json["gender"] =  "\(userAgeSexAndBloodType.biologicalSex.stringRepresentation)"
        json["bloodstype"] =  "\(userAgeSexAndBloodType.bloodType.stringRepresentation)"
        json["identifier"] = identity.components(separatedBy: "|")[0]
        json["zip"] = identity.components(separatedBy: "|")[1]
        json["loaddate"] = "\(Date())"

        var NO_ACTIVITY = true;
        
        // RUN A QUERY TO GET THE USERS EXERCISE FOR THIS DAY
        var activityQuery: HKSampleQuery {
           return HKSampleQuery(sampleType: HKSampleType.workoutType(),
                                predicate: pred,
                                limit: 0,
                                sortDescriptors: .none
           ) { (query, samples, error) in
             guard let workouts = samples as? [HKWorkout] else { return }
             print(workouts.count)
             // for each work out do something
             var activities: [String] = []
             
             for item in workouts {
               NO_ACTIVITY = false
               var workoutsARR:String = ""
               for act in item.workoutActivities {
                    workoutsARR = workoutsARR + "{'activity':'\(HKWorkoutActivityType(rawValue:act.workoutConfiguration.activityType.rawValue)?.name ?? "unk")', 'StartDate':'\(act.startDate.description.replacingOccurrences(of: " +0000", with: ""))','EndDate':'\(act.endDate!.description.replacingOccurrences(of: " +0000", with: ""))','Duration':\(act.duration)}"
                  
                    activities.append(workoutsARR)
                 
//                    let query = HKStatisticsQuery.init(quantityType: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
//                                                        quantitySamplePredicate:  HKQuery.predicateForSamples(withStart: act.startDate, end: act.endDate, options: HKQueryOptions.strictEndDate),
//                                                        options: HKStatisticsOptions.cumulativeSum) { (query, results, error) in
//
//                      workoutsARR = workoutsARR + ",'energy':\(results?.sumQuantity()?.doubleValue(for: HKUnit.largeCalorie()) ?? 0.0 )}"
//
//                      workoutsARR = workoutsARR.replacingOccurrences(of: "\"", with: "")
//                      activities.append(workoutsARR)
//
//                      DispatchQueue.global(qos: .background).async {
//                          DispatchQueue.main.async {
//                            self.afterActivity(activities: activities, d: date)
//                          }
//                      }
                      
//                 }
                 
//                 DataSend.self.healthStore.execute(query)

               } //end getting all workout activities
               
               
             } //list of all workouts
             
//             print("NO ACT", NO_ACTIVITY)
//             if (NO_ACTIVITY){
//               let a:[String] = [""]
//               self.afterActivity(activities: a, d:date)
//             }

           
             self.json["Activities"] = activities
             self.jsonReady(date:date) //GET DATA READY AND THEN FINALLY SEND
             
           } //work out query res
          
           
         }//end workout query
         
        DataSend.self.healthStore.execute(activityQuery) // run the exercise query above
        
      
      }catch {
          print(error.localizedDescription)
      }
      return
    }
  

    
    let identifier = targets[count]
    var id = NSObject()

    if identifier.contains("Category"){
      id = HKSampleType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier))!
    }else{
      id = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier))!
    }
        
    
    let query = HKSampleQuery(sampleType: id as! HKSampleType, predicate: pred, limit: 0, sortDescriptors: .none) {
         (sampleQuery, results, error) -> Void in
         if let result = results {
            var items:[String] = []
           
            for item in result {
              if let sample = item as? HKCategorySample {
                let uuid = sample.uuid
                let source = sample.sourceRevision.productType ?? ""
                let version = "\(sample.sourceRevision.operatingSystemVersion.majorVersion).\(sample.sourceRevision.operatingSystemVersion.minorVersion)"
                let sDate = sample.startDate.description.replacingOccurrences(of: " +0000", with: "")
                let eDate = sample.endDate.description.replacingOccurrences(of: " +0000", with: "")
                
                var str = "{'value': \(sample.value), 'uuid': '\(uuid)', 'source': '\(source)', 'version': '\(version)', 'start_time':'\(sDate)', 'end_time':'\(eDate)'}"
                
                str = str.replacingOccurrences(of: "\"", with: "")
                items.append(str)
                
              }
              
              if let sample = item as? HKQuantitySample {
                let val = sample.quantity.description.components(separatedBy: " ")
                let value = val[0]
                let unit = val[1]
                let uuid = sample.uuid
                let source = sample.sourceRevision.productType ?? ""
                let version = "\(sample.sourceRevision.operatingSystemVersion.majorVersion).\(sample.sourceRevision.operatingSystemVersion.minorVersion)"
                let sDate = sample.startDate.description.replacingOccurrences(of: " +0000", with: "")
                let eDate = sample.endDate.description.replacingOccurrences(of: " +0000", with: "")

                let metadata = sample.metadata
                
                var jsonMeta:String = ""
              
                if (metadata?["HKFoodMeal"]) != nil {
                  let foodtype = "\(metadata?["HKFoodType"]  ?? "")".replacingOccurrences(of: "'", with: "")
                  let foodImage = "\(metadata?["HKFoodImageName"]  ?? "")".replacingOccurrences(of: "'", with: "")
                  jsonMeta = "'foodImageName': '\(foodImage)','foodType': '\(foodtype)','USDANumber': '\(metadata?["HKFoodUSDANumber"]  ?? "")','meal': '\(metadata?["HKFoodMeal"] ?? "")'"
                }
                
                var str = "{'value': \(value), 'unit': '\(unit)', 'uuid': '\(uuid)', 'source': '\(source)', 'version': '\(version)', 'start_time':'\(sDate)', 'end_time':'\(eDate)', 'metadata':{\(jsonMeta)} }"
                
                
                str = str.replacingOccurrences(of: "\"", with: "")
                items.append(str)
              }
          }
          
          self.json[ self.targets[count] ] = items
          self.runquery(count: count + 1, date:date, identity: identity)
        }//end if
        
     }
    
    
    DataSend.self.healthStore.execute(query)
  
   }//end run query
   
  
  private func jsonReady(date:String){
    do{
      let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
      let jsonString = String(data: jsonData, encoding: String.Encoding.ascii)!
      var body:String = jsonString.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "").replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
      
//      print(body);// PRINT JSON VALUE TO SEND THRU THE WIRE
      // THIS WILL SEND DATE THRU POST - delivers data to the back end
      self.sendPost(body: body, date:date) //send data to snowpipe
      print("------------------")
    }catch{}
  }
  
  
  
  
//  private func afterActivity(activities:[String], d:String){
//    self.json["Activities"] = [ activities[activities.count-1] ]
//    print(activities[activities.count-1] )
//
//    do{
//      let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
//
//      let jsonString = String(data: jsonData, encoding: String.Encoding.ascii)!
//      var body:String = jsonString.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "").replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
//
////      print(body);// PRINT JSON VALUE TO SEND THRU THE WIRE
//      // THIS WILL SEND DATE THRU POST - delivers data to the back end
//      self.sendPost(body: body, date:d) //send data to snowpipe
//      print("------------------")
//    }catch {
//        print(error.localizedDescription)
//    }
//
//  }
  
  
  private func sendPost(body:String, date:String){
    print("Sending Post", date)
    let semaphore = DispatchSemaphore (value: 0)

    let parameters = "{\"body\":\(body)}"
    let postData = parameters.data(using: .utf8)

    var request = URLRequest(url: URL(string: "https://vtx9osi61g.execute-api.us-east-1.amazonaws.com/dev/send")!,timeoutInterval: Double.infinity)
    request.addValue("text/plain", forHTTPHeaderField: "Content-Type")

    request.httpMethod = "POST"
    request.httpBody = postData

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data else {
        print(String(describing: error))
        return
      }
      
      globals.postcount = globals.postcount + 1
      print("Sent - Snowpipe: \(body.count), post \(globals.postcount)")
      semaphore.signal()

  
    }

    task.resume()
    semaphore.wait()
  }//end end post
  
  
//  JUST NOT USED CODE -
//  private func sendHybrid(body:String){
//    //print("Sending Post")
//    let semaphore = DispatchSemaphore (value: 0)
//
//    let parameters = "\(body)"
//    let postData = parameters.data(using: .utf8)
//
//    var request = URLRequest(url: URL(string: "https://htnzoeguwg.execute-api.us-east-1.amazonaws.com/dev/write")!,timeoutInterval: Double.infinity)
//    request.addValue("text/plain", forHTTPHeaderField: "Content-Type")
//
//    request.httpMethod = "POST"
//    request.httpBody = postData
//
//    let task = URLSession.shared.dataTask(with: request) { data, response, error in
//      guard let data = data else {
//        print(String(describing: error))
//        return
//      }
//      //print("Sent - Hybrid: \(String(data: data, encoding: .utf8)!)")
//      semaphore.signal()
//
//    }
//
//    task.resume()
//    semaphore.wait()
//  }//end end post
//
  
  
  
}//end class


extension Dictionary {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}


extension HKWorkoutActivityType {

    /*
     Simple mapping of available workout types to a human readable name.
     */
    var name: String {
        switch self {
        case .americanFootball:             return "American Football"
        case .archery:                      return "Archery"
        case .australianFootball:           return "Australian Football"
        case .badminton:                    return "Badminton"
        case .baseball:                     return "Baseball"
        case .basketball:                   return "Basketball"
        case .bowling:                      return "Bowling"
        case .boxing:                       return "Boxing"
        case .climbing:                     return "Climbing"
        case .crossTraining:                return "Cross Training"
        case .curling:                      return "Curling"
        case .cycling:                      return "Cycling"
        case .dance:                        return "Dance"
        case .danceInspiredTraining:        return "Dance Inspired Training"
        case .elliptical:                   return "Elliptical"
        case .equestrianSports:             return "Equestrian Sports"
        case .fencing:                      return "Fencing"
        case .fishing:                      return "Fishing"
        case .functionalStrengthTraining:   return "Functional Strength Training"
        case .golf:                         return "Golf"
        case .gymnastics:                   return "Gymnastics"
        case .handball:                     return "Handball"
        case .hiking:                       return "Hiking"
        case .hockey:                       return "Hockey"
        case .hunting:                      return "Hunting"
        case .lacrosse:                     return "Lacrosse"
        case .martialArts:                  return "Martial Arts"
        case .mindAndBody:                  return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
        case .paddleSports:                 return "Paddle Sports"
        case .play:                         return "Play"
        case .preparationAndRecovery:       return "Preparation and Recovery"
        case .racquetball:                  return "Racquetball"
        case .rowing:                       return "Rowing"
        case .rugby:                        return "Rugby"
        case .running:                      return "Running"
        case .sailing:                      return "Sailing"
        case .skatingSports:                return "Skating Sports"
        case .snowSports:                   return "Snow Sports"
        case .soccer:                       return "Soccer"
        case .softball:                     return "Softball"
        case .squash:                       return "Squash"
        case .stairClimbing:                return "Stair Climbing"
        case .surfingSports:                return "Surfing Sports"
        case .swimming:                     return "Swimming"
        case .tableTennis:                  return "Table Tennis"
        case .tennis:                       return "Tennis"
        case .trackAndField:                return "Track and Field"
        case .traditionalStrengthTraining:  return "Traditional Strength Training"
        case .volleyball:                   return "Volleyball"
        case .walking:                      return "Walking"
        case .waterFitness:                 return "Water Fitness"
        case .waterPolo:                    return "Water Polo"
        case .waterSports:                  return "Water Sports"
        case .wrestling:                    return "Wrestling"
        case .yoga:                         return "Yoga"

        // iOS 10
        case .barre:                        return "Barre"
        case .coreTraining:                 return "Core Training"
        case .crossCountrySkiing:           return "Cross Country Skiing"
        case .downhillSkiing:               return "Downhill Skiing"
        case .flexibility:                  return "Flexibility"
        case .highIntensityIntervalTraining:    return "High Intensity Interval Training"
        case .jumpRope:                     return "Jump Rope"
        case .kickboxing:                   return "Kickboxing"
        case .pilates:                      return "Pilates"
        case .snowboarding:                 return "Snowboarding"
        case .stairs:                       return "Stairs"
        case .stepTraining:                 return "Step Training"
        case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
        case .wheelchairRunPace:            return "Wheelchair Run Pace"

        // iOS 11
        case .taiChi:                       return "Tai Chi"
        case .mixedCardio:                  return "Mixed Cardio"
        case .handCycling:                  return "Hand Cycling"

        // iOS 13
        case .discSports:                   return "Disc Sports"
        case .fitnessGaming:                return "Fitness Gaming"

        // Catch-all
        default:                            return "Other"
        }
    }

}
