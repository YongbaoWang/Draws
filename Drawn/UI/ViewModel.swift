//
//  ViewModel.swift
//  DrawerGame
//
//  Created by Roman Mazeev on 18.04.2020.
//  Copyright © 2020 Roman Mazeev. All rights reserved.
//

import SwiftUI
import Combine

class ViewModel: ObservableObject {
    @Published var drawing = [[CGPoint]]()

    @Published private(set) var prediction = ""
    @Published private(set) var drawingTask = TaskDataSource.tasks.randomElement()
    @Published var isCompleted = false

    private var cancellables: Set<AnyCancellable> = .init()
    private var predictionCancellables: Set<AnyCancellable> = .init()

    private let mlService = MLService()

    init() {
        $drawing
            .filter { $0 != [] }
            .throttle(for: 1, scheduler: DispatchQueue.global(), latest: true)
            .sink { drawing in
                self.predict(using: drawing)
            }
            .store(in: &cancellables)

        $prediction
            .filter { $0 == self.drawingTask }
            .sink { prediction in
                self.isCompleted = true
                self.mlService.updateModel(image: Drawing(drawing: self.drawing).rasterized, classLabel: prediction)
            }
            .store(in: &cancellables)
    }

    func clean() {
        drawing = []
        prediction = ""
        predictionCancellables.forEach { $0.cancel() }
    }

    func nextTask() {
        clean()
        drawingTask = TaskDataSource.tasks.randomElement()
    }

    func rememberDrawing() {
        mlService.updateModel(image: Drawing(drawing: drawing).rasterized, classLabel: drawingTask!)
        nextTask()
    }

    func resetPredictor() {
        mlService.resetDrawingClassifier()
    }

    private func predict(using drawing: [[CGPoint]]) {
        mlService.predict(image: Drawing(drawing: drawing).rasterized)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { prediction in
                    self.prediction = prediction
                }
            )
            .store(in: &predictionCancellables)
    }
}
