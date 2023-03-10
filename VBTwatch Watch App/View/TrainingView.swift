//
//  TrainingView.swift
//  VBTwatch Watch App
//
//  Created by Hiroki Kawamura on 2023/03/08.
//

import SwiftUI

struct TrainingView: View {
    @ObservedObject var activityClassifier = ActivityClassifier()
    @Binding var trainingData: TrainingData
    @State var data = TrainingData.Data()
    @State var canTransitionToSummary = false
    @State var canTransitionToHome = false
    @State var canTransitionToRest = false
    @State var showingAlert = false
    @State var currentSet = TrainingSet.sampleSet
    @State var isFirst = true
    @State var isBackFromAlert = false
    var currentRep: TrainingRep {
        get {
            if currentSet.reps.count != 0 {
                return currentSet.reps[currentSet.reps.count-1]
            }
            else {
                return TrainingRep.sampleRep
            }
        }
    }
    var currentSetCount: Int {
        get { data.sets.count + 1 }
    }
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Text("\(currentSetCount)/\(trainingData.setCount)").font(.system(size: 20))
                    Text("セット")
                    Spacer()
                }
                HStack {
                    Text(String(currentSet.reps.count)).font(.system(size: 20))
                    Text("レップ")
                    Spacer()
                }
                HStack {
                    Text(String(trainingData.objective.velocity)).font(.system(size: 20))
                    VStack {
                        HStack {
                            Text("目標挙上速度")
                            Spacer()
                        }
                        HStack{
                            Text("m/s")
                            Spacer()
                        }
                    }.font(.system(size: 10))
                    Spacer()
                }
                HStack {
                    Text(String(roundVelocity(velocity: currentRep.velocity))).font(.system(size: 20))
                    VStack {
                        HStack {
                            Text("挙上速度")
                            Spacer()
                        }
                        HStack{
                            Text("m/s")
                            Spacer()
                        }
                    }.font(.system(size: 10))
                    Spacer()
                }
                HStack {
                    Text(String(currentRep.velocityLoss)).font(.system(size: 20))
                    VStack {
                        HStack {
                            Text("速度低下率")
                            Spacer()
                        }
                        HStack{
                            Text("%")
                            Spacer()
                        }
                    }.font(.system(size: 10))
                    Spacer()
                }
            }.padding()
            HStack {
                ButtonView(activityClassifier: activityClassifier, canTransition: $canTransitionToSummary, label: "終了", color: Color.red)
                ButtonView(activityClassifier: activityClassifier, canTransition: $canTransitionToSummary, label: activityClassifier.isStarted ? "一時停止" : "再開", color: Color.yellow)
            }
            if canTransitionToSummary {
                NavigationLink(destination: SummaryView(trainingData: $trainingData), isActive: $canTransitionToSummary) {
                    EmptyView()
                }
            }
            if canTransitionToHome {
                NavigationLink(destination: HomeView(), isActive: $canTransitionToHome) {
                    EmptyView()
                }
            }
            if canTransitionToRest {
                NavigationLink(destination: RestView(), isActive: $canTransitionToRest) {
                    EmptyView()
                }
            }
        }.onChange(of: activityClassifier.velocityPerRep, perform: { newVelocity in
            if newVelocity == 0.0 { return }
            let velocityLoss = calculateVelocityLoss(velocity: newVelocity)
            let targetError = calculateTargetError(velocity: newVelocity)
            if isFirst {
                isFirst = false
                alertIfNeeded(targetError: targetError)
            }
            print(newVelocity)
            speechText(text: String(roundVelocity(velocity: newVelocity)))
            storeRepData(velocity: newVelocity, velocityLoss: velocityLoss, targetError: targetError)
            finishIfNeeded(velocityLoss: velocityLoss)
        })
        .alert(
            "目的や重量を変更しますか？",
            isPresented: $showingAlert
        ) {
            Button("はい") {
                canTransitionToHome = true
            }
            Button("いいえ") {
                isBackFromAlert = true
            }
        } message: {
            Text("挙上速度と目標速度の差が\(String(currentRep.targetError))と大きいです。")
        }
        .onAppear {
            activityClassifier.startManageMotionData()
            if !isBackFromAlert {
                WKInterfaceDevice.current().play(.notification)
                speechText(text: "\(currentSetCount)レップめ開始")
            }
            isBackFromAlert = false
        }
        .navigationBarBackButtonHidden(true)
    }
    
    func calculateVelocityLoss(velocity: Double) -> Int {
        let maxVelocity = getMaxVelocity()
        if maxVelocity == 0 { return 0 }
        
        let variation = roundVelocity(velocity: maxVelocity) - roundVelocity(velocity:velocity)
        if variation < 0 {
            return Int(variation / roundVelocity(velocity: velocity) * 100)
        }
        else {
            return Int(variation / roundVelocity(velocity: maxVelocity) * 100)
        }
    }
    
    func calculateTargetError(velocity: Double) -> Double {
        return roundVelocity(velocity: velocity-trainingData.objective.velocity)
    }
    
    func getMaxVelocity() -> Double {
        let maxVelocityOrNil = currentSet.reps.max(by: { (a, b) -> Bool in
            return a.velocity < b.velocity
        })?.velocity
        
        guard let maxVelocity = maxVelocityOrNil else {
            return 0
        }
        return roundVelocity(velocity: maxVelocity)
    }
    
    func calculateAverageVelocity() -> Double {
        let velocityPerRepArray = currentSet.reps.map { $0.velocity }
        let sumVelocityPerSet = velocityPerRepArray.reduce(0, +)
        return roundVelocity(velocity: sumVelocityPerSet/Double(currentSet.reps.count))
    }
    
    func storeRepData(velocity: Double, velocityLoss: Int, targetError: Double) {
        let rep = TrainingRep(velocity: velocity, velocityLoss: velocityLoss, targetError: targetError)
        currentSet.reps.append(rep)
    }
    
    func storeSetData() {
        let set = TrainingSet(reps: currentSet.reps, averageVelocity: calculateAverageVelocity(), maxVelocity: getMaxVelocity())
        data.sets.append(set)
        initializeCurrentSetData()
    }
    
    func initializeCurrentSetData() {
        currentSet = TrainingSet.sampleSet
    }
    
    func alertIfNeeded(targetError: Double) {
        let MAX_PERMISSIBLE_ERROR = 0.15
        if abs(targetError) >  MAX_PERMISSIBLE_ERROR {
            self.activityClassifier.stopManageMotionData()
            WKInterfaceDevice.current().play(.notification)
            showingAlert = true
        }
    }
    
    func finishIfNeeded(velocityLoss: Int) {
        if velocityLoss < trainingData.maxVelocityLoss { return }
        activityClassifier.stopManageMotionData()
        storeSetData()
        WKInterfaceDevice.current().play(.notification)
        speechText(text: "\(data.sets.count)レップめ終了")
        if data.sets.count < trainingData.setCount {
            canTransitionToRest = true
        } else {
            trainingData.update(from: data)
            canTransitionToSummary = true
        }
    }
}

struct TrainingView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingView(trainingData: .constant(TrainingData.sampleData[0]))
    }
}
