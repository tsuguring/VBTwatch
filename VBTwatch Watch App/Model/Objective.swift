//
//  Objective.swift
//  VBTwatch Watch App
//
//  Created by Ryo Yoshitsugu on R 5/03/07.
//

import Foundation

struct Objective {
    var title: String
    var velocity: Double
    var weight: String
    var image: String
}

extension Objective {
    static let sampleData: [Objective] =
    [
        Objective(title: "筋肥大", velocity: 0.46, weight: "80%", image: "figure.strengthtraining.traditional"),
        Objective(title: "スピード筋力", velocity: 0.94, weight: "50%", image: "figure.core.training")
    ]
}