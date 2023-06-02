import UIKit
import HealthKit

class MasterViewController: UITabBarController {
  //static let healthStore = HKHealthStore()
  var json:[String : Any] = [:]
  //https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier
  static var targets:[String] =
  [HKQuantityTypeIdentifier.bodyMassIndex.rawValue,
   HKQuantityTypeIdentifier.bodyMass.rawValue,
   HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
   HKQuantityTypeIdentifier.stepCount.rawValue,
   HKQuantityTypeIdentifier.flightsClimbed.rawValue,
   HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
   HKQuantityTypeIdentifier.dietaryWater.rawValue,
   HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue,
   HKQuantityTypeIdentifier.dietaryProtein.rawValue,
   HKQuantityTypeIdentifier.dietaryFatTotal.rawValue,
   HKQuantityTypeIdentifier.dietaryFatSaturated.rawValue,
   HKQuantityTypeIdentifier.dietaryFatMonounsaturated.rawValue,
   HKQuantityTypeIdentifier.dietaryFatPolyunsaturated.rawValue,
   HKQuantityTypeIdentifier.dietaryCholesterol.rawValue,
   HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue,
   HKQuantityTypeIdentifier.dietarySodium.rawValue,
   HKQuantityTypeIdentifier.dietarySugar.rawValue,
   HKQuantityTypeIdentifier.basalEnergyBurned.rawValue,
   HKQuantityTypeIdentifier.waistCircumference.rawValue,
   HKQuantityTypeIdentifier.heartRate.rawValue,
   HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue,
   HKQuantityTypeIdentifier.restingHeartRate.rawValue,
   HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue,
   HKQuantityTypeIdentifier.environmentalAudioExposure.rawValue,
   HKQuantityTypeIdentifier.headphoneAudioExposure.rawValue,
   HKQuantityTypeIdentifier.appleStandTime.rawValue,
   HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
   HKCategoryType(.sleepAnalysis).identifier
  ]

  
//  static var sleep_targets:[HKCategoryTypeIdentifier] = [
//    HKCategoryTypeIdentifier.sleepAnalysis
//  ]
  

  override func viewDidLoad() {
    super.viewDidLoad()
    UIApplication.shared.isIdleTimerDisabled = true
    authorizeHealthKit()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  private func authorizeHealthKit() {
    HealthKitSetupAssistant.authorizeHealthKit { (authorized, error) in
      guard authorized else {
        let baseMessage = "HealthKit Authorization Failed"
        
        guard let error = error else { print(baseMessage); return }
        print("\(baseMessage). Reason: \(error.localizedDescription)")
        return
      }
      print("HealthKit Successfully Authorized.")
    }
  }


}



