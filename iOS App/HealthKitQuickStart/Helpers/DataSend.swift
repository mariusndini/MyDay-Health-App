
import Foundation
import HealthKit
import UIKit

class DataSend{
  
  static let healthStore = HKHealthStore()
  var json:[String : Any] = [:]
  var targets = MasterViewController.targets

  
  /******  Runs Query for specificed identifier given   ******/
  public func runquery(count:Int, date:String, identity:String){
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

        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        let jsonString = String(data: jsonData, encoding: String.Encoding.ascii)!
        let body:String = jsonString.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
          //                         .replacingOccurrences(of: "'", with: "") // ERRORS OUT WHEN DATA IS UPLOADED W/ THIS
          //                         .replacingOccurrences(of: "\\", with: "")
          //                         .replacingOccurrences(of: "\n", with: "")
          //                         .replacingOccurrences(of: ";", with: "")
          //                         .replacingOccurrences(of: "=", with: ":")
          //                         .replacingOccurrences(of: "", with: "")
        
        
        print(body);
        // THIS WILL SEND DATE THRU POST
        self.sendPost(body: body) //send data to snowpipe
//        self.sendHybrid(body:body) //send data to hybrid table
      }catch {
          print(error.localizedDescription)
      }
      return
    }
  

    let identifier = targets[count]
    guard let id = HKSampleType.quantityType(forIdentifier: identifier) else {
       return
     }
    
     let formatter = DateFormatter()
     formatter.dateFormat = "yyyy/MM/dd"
     let endTime = formatter.date(from: date)!
      
     let daysAgo = NSCalendar.current.date(byAdding: .day, value: -1, to: endTime)
     let pred = HKQuery.predicateForSamples(withStart: daysAgo, end: endTime, options: [])
    
     let query = HKSampleQuery(sampleType: id, predicate: pred, limit: 0, sortDescriptors: .none) {
         (sampleQuery, results, error) -> Void in
         if let result = results {
            var items:[String] = []
            for item in result {
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
          
          self.json[ self.targets[count].rawValue ] = items
          self.runquery(count: count + 1, date:date, identity: identity)
        }//end if
        
     }
     
    DataSend.self.healthStore.execute(query)
    
   }//end run query
   
  
  
  private func sendPost(body:String){
    print("Sending Post")
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
      print("Sent - Snowpipe: \(String(data: data, encoding: .utf8)!)")
      globals.postcount = globals.postcount + 1
      semaphore.signal()

  
    }

    task.resume()
    semaphore.wait()
  }//end end post
  
  private func sendHybrid(body:String){
    //print("Sending Post")
    let semaphore = DispatchSemaphore (value: 0)

    let parameters = "\(body)"
    let postData = parameters.data(using: .utf8)

    var request = URLRequest(url: URL(string: "https://htnzoeguwg.execute-api.us-east-1.amazonaws.com/dev/write")!,timeoutInterval: Double.infinity)
    request.addValue("text/plain", forHTTPHeaderField: "Content-Type")

    request.httpMethod = "POST"
    request.httpBody = postData

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data else {
        print(String(describing: error))
        return
      }
      //print("Sent - Hybrid: \(String(data: data, encoding: .utf8)!)")
      semaphore.signal()
  
    }

    task.resume()
    semaphore.wait()
  }//end end post
  
  
  
  
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


