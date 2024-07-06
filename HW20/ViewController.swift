import UIKit

class ViewController: UIViewController {

    let textField = UITextField()
    let slider = UISlider()
    let startButton = UIButton(type: .system)
    let pauseButton = UIButton(type: .system)
    let progressView = UIProgressView(progressViewStyle: .default)

    let sieve = Sieve()
    var sieveTask: Task<Void, Never>? = nil
    var isPaused = false
    var currentNumber: Int?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    @objc func startButtonTapped() {
        isPaused = false
        cancelSieveTask()
        resetUI()
        startSieveTask()
    }

    @objc func pauseButtonTapped() {
        isPaused = true
        cancelSieveTask()
        updateTextFieldColor()
    }

    @objc func sliderValueChanged() {
        if !isPaused {
            cancelSieveTask()
            startSieveTask()
        }
    }

    func cancelSieveTask() {
        sieveTask?.cancel()
    }

    func startSieveTask() {
        sieveTask = Task {
            await runSieve()
        }
    }

    func resetUI() {
        Task {@MainActor in
                self.progressView.progress = 0.0
                self.textField.backgroundColor = .white
            
            await sieve.reset()
        }
    }

    func updateTextFieldColor() {
        guard let number = currentNumber else { return }
        Task {@MainActor in
            let isPrime = await sieve.checkPrime(number: number)
             
                self.textField.backgroundColor = isPrime ? .green : .red
            }
        }
    

    func runSieve() async {
        let delay = slider.value == 0 ? 0.0 : Double(slider.value) / 1000.0
        
        currentNumber = Int(textField.text ?? "0")
        
        await sieve.sieve(withDelay: delay, isPaused: { [weak self] in self?.isPaused ?? false }, updateProgress: { [weak self] progress in
            guard let self = self else { return }
            Task {
                self.progressView.progress = progress
            }
        })
        
        print("Complete")
        
        updateTextFieldColor()
    }

    func setupUI() {
        // Set up the TextField
        textField.placeholder = "Enter text"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)

        // Set up the Slider
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(slider)

        // Set up the Start Button
        startButton.setTitle("Start", for: .normal)
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startButton)

        // Set up the Pause Button
        pauseButton.setTitle("Pause", for: .normal)
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pauseButton)

        // Set up the Progress View
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        // Set up constraints
        NSLayoutConstraint.activate([
            // TextField constraints
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 140),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Slider constraints
            slider.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Start Button constraints
            startButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 20),
            startButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: -60),

            // Pause Button constraints
            pauseButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 20),
            pauseButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: 60),

            // Progress View constraints
            progressView.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
}

actor Sieve {
    private var numbers = Array(repeating: true, count: 10_000_000)
    private var currentIdx: Int = 1

    func reset() {
        numbers = Array(repeating: true, count: 10_000_000)
        currentIdx = 1
    }

    func sieve(withDelay delay: Double, isPaused: @escaping () -> Bool, updateProgress: @escaping (Float) -> Void) async {
        numbers[0] = false
        numbers[1] = false
        let total = numbers.count

        while currentIdx < numbers.count {
            guard let n = numbers[currentIdx...].firstIndex(of: true) else { break }
            currentIdx = n + 1

            for i in stride(from: n, to: numbers.count, by: n).dropFirst() {
                numbers[i] = false

                if delay > 0 {
                    do {
                        try await Task.sleep(for: .seconds(delay * 1))
                    } catch {
                        print("Sleep interrupted")
                    }
                }

                if isPaused() {
                    return
                }
            }

            let progress = Float(currentIdx) / Float(total)
            updateProgress(progress)
        }
    }

    func checkPrime(number: Int) async -> Bool {
        guard number >= 0 && number < numbers.count else { return false }
        return await withUnsafeContinuation { continuation in
            Task {
                continuation.resume(returning: self.numbers[number])
            }
        }
    }
}
