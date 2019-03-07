//
//  ViewController.swift
//  CatFactsWithNsOperationQueues
//
//  Created by lukas2 on 07.03.19.
//  Copyright © 2019 lukas2. All rights reserved.
//

import UIKit

struct CatFact: Decodable {
    var text: String
}

class OperationWithUserData: Operation {
    var userData: Any?
}

class FetchOperation: OperationWithUserData {
    override func main() {
        sleep(arc4random() % 5)
        let url = URL(string: "https://cat-fact.herokuapp.com/facts/random")!
        userData = try? Data(contentsOf: url)
    }
}

class ParseOperation: OperationWithUserData {
    override func main() {
        if let userData = userData as? Data {
            let decoder = JSONDecoder()
            if let catFact = try? decoder.decode(CatFact.self, from: userData) {
                self.userData = catFact
            }
        }
    }
}

class AdapterOperation: Operation {
    weak var firstOperation: OperationWithUserData?
    weak var secondOperation: OperationWithUserData?
    
    init(firstOperation: OperationWithUserData, secondOperation: OperationWithUserData) {
        self.firstOperation = firstOperation
        self.secondOperation = secondOperation
    }
    
    override func main() {
        if let firstOperation = firstOperation,
            let secondOperation = secondOperation {
            secondOperation.userData = firstOperation.userData
        }
    }
}

class DisplayOperation: OperationWithUserData {
    weak var textView: UITextView?
    
    init(textView: UITextView) {
        self.textView = textView
    }
    
    override func main() {
        if let catFact = userData as? CatFact,
            let textView = textView {
            DispatchQueue.main.async { // perhaps use .sync here if another operation is to be executed afterwards.
                textView.text = catFact.text
            }
        }
    }
}

class ViewController: UIViewController {
    
    // This is based on: https://medium.com/@marcosantadev/4-ways-to-pass-data-between-operations-with-swift-2fa5b3a3d561

    @IBOutlet var textView: UITextView!
    private let queue = OperationQueue()
    private var counter = 0 {
        didSet {
            print("counter: \(counter)")
        }
    }

    @IBAction func onTap() {
        counter += 1

        let fetch = FetchOperation()
        let parse = ParseOperation()
        let display = DisplayOperation(textView: textView)
        
        display.completionBlock = {
            self.counter -= 1
        }
        
        // Use adapter operations to move data, because completion blocks would not work (they would execute after next operation starts).
        let fetchToParse = AdapterOperation(firstOperation: fetch, secondOperation: parse)
        let parseToDisplay = AdapterOperation(firstOperation: parse, secondOperation: display)
        
        // FETCH - FETCHTOPARSE - PARSE
        fetchToParse.addDependency(fetch)
        parse.addDependency(fetchToParse)
        
        // PARSE - PARSETODISPLAY - DISPLAY
        parseToDisplay.addDependency(parse)
        display.addDependency(parseToDisplay)
        
        queue.addOperations([fetch, parse, display, fetchToParse, parseToDisplay], waitUntilFinished: false)
    }
}

