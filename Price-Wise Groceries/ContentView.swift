import SwiftUI

struct ContentView: View {
    @State private var vectorsText: String = ""
    @State private var selectedProvince: String = "Canada"
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2024
    @State private var results: [String: [(year: Int, month: Int, value: String, product: String)]] = [:]
    @State private var isLoadingData = false
    @State private var errorMessage: String? = nil

    let provinces = ["Canada", "Nova Scotia", "Ontario", "Newfoundland and Labrador",
                     "Prince Edward Island", "New Brunswick", "Quebec", "Manitoba",
                     "Saskatchewan", "Alberta", "British Columbia"]
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let years = Array(2020...2024)
    private let calendar = Calendar.current

    var body: some View {
        NavigationView {
            VStack {
                InputAndSelectionView(vectorsText: $vectorsText, selectedProvince: $selectedProvince, selectedMonth: $selectedMonth, selectedYear: $selectedYear)

                Button(action: {
                    isLoadingData = true
                    fetchValueData()
                }) {
                    Text("Get Values")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(isLoadingData)

                if isLoadingData {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else if !results.isEmpty {
                    ResultsTableView(results: results, months: months, selectedYear: selectedYear, selectedMonth: selectedMonth)
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Data Viewer")
            .padding()
        }
    }

    func fetchValueData() {
        isLoadingData = true
        errorMessage = nil
        results.removeAll()

        let vectors = vectorsText.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        let group = DispatchGroup()
        for vector in vectors {
            for year in years {
                group.enter()
                fetchDataForVector(vector, year: year, month: selectedMonth, group: group)
            }
        }

        group.notify(queue: .main) {
            isLoadingData = false
        }
    }

    func fetchDataForVector(_ vector: String, year: Int, month: Int, group: DispatchGroup) {
        let startDate = "\(year)-\(String(format: "%02d", month))-01"

        var dateComponents = calendar.dateComponents([.year, .month], from: Date())
        dateComponents.year = year
        dateComponents.month = month
        guard let date = calendar.date(from: dateComponents) else {
            handleFetchError("Error creating date", group: group)
            return
        }
        let endDate = "\(year)-\(String(format: "%02d", month))-\(calendar.component(.day, from: date))"

        let apiUrl = "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromVectorByReferencePeriodRange?vectorIds=\(vector)&startRefPeriod=\(startDate)&endReferencePeriod=\(endDate)"

        print("Fetching data for vector: \(vector), year: \(year), month: \(month)")
        print("API URL: \(apiUrl)")

        guard let url = URL(string: apiUrl) else {
            handleFetchError("Invalid API URL", group: group)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { group.leave() }

            if let error = error {
                handleFetchError("Error fetching data: \(error.localizedDescription)", group: group)
                return
            }

            guard let data = data else {
                handleFetchError("No data received for vector \(vector)", group: group)
                return
            }

            do {
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode([APIResponse].self, from: data)

                if let value = apiResponse.first?.object?.vectorDataPoint.first?.value {
                    fetchSeriesInfo(for: vector) { productString in
                        DispatchQueue.main.async {
                            if self.results[vector] == nil {
                                self.results[vector] = []
                            }
                            self.results[vector]?.append((year: year, month: selectedMonth, value: String(format: "%.2f", value), product: productString))
                        }
                    }
                } else {
                    handleFetchError("Value not found for VECTOR: \(vector)", group: group)
                }
            } catch {
                handleFetchError("Error decoding data: \(error.localizedDescription)", group: group)
            }
        }.resume()
    }

    func fetchSeriesInfo(for vector: String, completion: @escaping (String) -> Void) {
        let apiUrl = "https://www150.statcan.gc.ca/t1/wds/rest/getSeriesInfoFromVector"

        print("Fetching product info for vector: \(vector)")
        print("API URL for product info: \(apiUrl)")

        guard let url = URL(string: apiUrl) else {
            completion("Product not found")
            return
        }

        guard let vectorId = Int(vector) else {
            completion("Invalid vector ID")
            return
        }

        let requestBody = [["vectorId": vectorId]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching product info for vector \(vector): \(error.localizedDescription)")
                completion("Error fetching product")
                return
            }

            guard let data = data else {
                print("No data received for product info for vector \(vector)")
                completion("Product not found")
                return
            }

            print("Raw JSON response for product info: \(String(data: data, encoding: .utf8)!)")

            do {
                let decoder = JSONDecoder()
                let seriesResponse = try decoder.decode([SeriesInfoResponse].self, from: data)
                if let productString = seriesResponse.first?.object?.SeriesTitleEn {
                    let productName = productString.components(separatedBy: ";").last?.trimmingCharacters(in: .whitespaces) ?? "Product not found"
                    completion(productName)
                } else {
                    print("Product name not found in JSON response for vector \(vector)")
                    completion("Product not found")
                }
            } catch {
                print("Error decoding series info: \(error)")
                completion("Error fetching product")
            }
        }.resume()
    }

    func handleFetchError(_ message: String, group: DispatchGroup) {
        DispatchQueue.main.async {
            errorMessage = message
            print(message)
            isLoadingData = false
            group.leave()
        }
    }
}

struct InputAndSelectionView: View {
    @Binding var vectorsText: String
    @Binding var selectedProvince: String
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int

    let provinces = ["Canada", "Nova Scotia", "Ontario", "Newfoundland and Labrador",
                     "Prince Edward Island", "New Brunswick", "Quebec", "Manitoba",
                     "Saskatchewan", "Alberta", "British Columbia"]
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let years = Array(2020...2024)

    var body: some View {
        VStack {
            TextEditor(text: $vectorsText)
                .border(Color.gray, width: 1)
                .padding()
                .frame(height: 100)

            Picker("Select Province", selection: $selectedProvince) {
                ForEach(provinces, id: \.self) { province in
                    Text(province)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            HStack {
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1..<13,id: \.self) { month in
                        Text(months[month - 1])
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()

                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)")
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
            }
        }
    }
}

struct ResultsTableView: View {
    let results: [String: [(year: Int, month: Int, value: String, product: String)]]
    let months: [String]
    let selectedYear: Int
    let selectedMonth: Int // Add this line

    var body: some View {
        List {
            ForEach(Array(results.keys), id: \.self) { vector in
                Section(header: Text("Vector: \(vector)")) {
                    // Find the result for the selected month and year
                    if let selectedResult = results[vector]?.first(where: { $0.year == selectedYear && $0.month == selectedMonth }) {
                        HStack {
                            Text(selectedResult.product)
                            Spacer()
                            Text("$\(selectedResult.value)")
                        }
                    }

                    // Calculate and display the average price since 2020
                    let averagePrice = calculateAverage(for: results[vector]!)
                    HStack {
                        Text("Average Price for \(months[selectedMonth - 1]) Since 2020:")
                        Spacer()
                        Text(averagePrice)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    func calculateAverage(for results: [(year: Int, month: Int, value: String, product: String)]) -> String {
        let filteredResults = results.filter { $0.month == selectedMonth && $0.year >= 2020 }
        guard !filteredResults.isEmpty else { return "N/A" }
        let total = filteredResults.compactMap { Double($0.value) }.reduce(0, +)
        let average = total / Double(filteredResults.count)
        return String(format: "$%.2f", average) // Add the dollar sign here
    }
}
