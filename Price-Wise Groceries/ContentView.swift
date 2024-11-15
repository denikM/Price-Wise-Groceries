import SwiftUI

struct ContentView: View {
    @State private var vectorsText: String = ""
    @State private var selectedProvince: String = "Canada"
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2024
    @State private var results: [String: (value: String, product: String)] = [:]
    @State private var isLoadingData = false
    @State private var errorMessage: String? = nil

    let provinces = ["Canada", "Nova Scotia", "Ontario", "Newfoundland and Labrador",
                     "Prince Edward Island", "New Brunswick", "Quebec", "Manitoba",
                     "Saskatchewan", "Alberta", "British Columbia"]
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let years = Array(2017...2024)

    var body: some View {
        NavigationView {
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
                        ForEach(1..<13, id: \.self) { month in
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
                    List {
                        ForEach(Array(results.keys), id: \.self) { vector in
                            if let result = results[vector] {
                                Text("Vector: \(vector), Value: \(result.value), Product: \(result.product)")
                            }
                        }
                    }
                    .listStyle(.plain)
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
            group.enter()

            let startDate = "\(selectedYear)-\(String(format: "%02d", selectedMonth))-01"
            let endDate = "\(selectedYear)-\(String(format: "%02d", selectedMonth))-31"
            let apiUrl = "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromVectorByReferencePeriodRange?vectorIds=\(vector)&startRefPeriod=\(startDate)&endReferencePeriod=\(endDate)"

            print("Fetching data for vector: \(vector)")
            print("API URL: \(apiUrl)")

            guard let url = URL(string: apiUrl) else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid API URL"
                    isLoadingData = false
                }
                return
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                if let error = error {
                    DispatchQueue.main.async {
                        errorMessage = "Error fetching data: \(error.localizedDescription)"
                        print("Error fetching data for vector \(vector): \(error.localizedDescription)")
                    }
                    return
                }

                guard let data = data else {
                    DispatchQueue.main.async {
                        errorMessage = "No data received for vector \(vector)"
                        print("No data received for vector \(vector)")
                    }
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    let apiResponse = try decoder.decode([APIResponse].self, from: data)

                    if let value = apiResponse.first?.object?.vectorDataPoint.first?.value {
                        // Fetch series information to get the product string
                        fetchSeriesInfo(for: vector) { productString in
                            DispatchQueue.main.async {
                                self.results[vector] = (value: String(format: "%.2f", value), product: productString)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            errorMessage = "Value not found for VECTOR: \(vector)"
                            print("Value not found for VECTOR: \(vector)")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        errorMessage = "Error decoding data: \(error.localizedDescription)"
                        print("Error decoding data for vector \(vector): \(error.localizedDescription)")
                    }
                }
            }.resume()
        }

        group.notify(queue: .main) {
            isLoadingData = false
        }
    }

    func fetchSeriesInfo(for vector: String, completion: @escaping (String) -> Void) {
        let apiUrl = "https://www150.statcan.gc.ca/t1/wds/rest/getSeriesInfoFromVector"

        print("Fetching product info for vector: \(vector)")
        print("API URL for product info: \(apiUrl)")

        guard let url = URL(string: apiUrl) else {
            completion("Product not found")
            return
        }

        // Assuming vector is convertible to Int
        guard let vectorId = Int(vector) else {
            completion("Invalid vector ID")
            return
        }

        let requestBody = [["vectorId": vectorId]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody
 = try? JSONEncoder().encode(requestBody)

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
                    // Split the product string by semicolon and take the last part
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
}


// Data Models
struct APIResponse: Decodable {
    let status: String
    let object: APIObject?
}

struct APIObject: Decodable {
    let responseStatusCode: Int
    let productId: Int
    let coordinate: String
    let vectorId: Int
    let vectorDataPoint: [VectorDataPoint]
}

struct VectorDataPoint: Decodable {
    let refPer: String
    let refPer2: String?
    let refPerRaw: String
    let refPerRaw2: String?
    let value: Double
    let decimals: Int
    let scalarFactorCode: Int
    let symbolCode: Int
    let statusCode: Int
    let securityLevelCode: Int
    let releaseTime: String
    let frequencyCode: Int
}

struct SeriesInfoResponse: Decodable {
    let status: String
    let object: SeriesInfoObject?
}

struct SeriesInfoObject: Decodable {
    let responseStatusCode: Int
    let productId: Int
    let coordinate: String
    let vectorId: Int
    let frequencyCode: Int
    let scalarFactorCode: Int
    let decimals: Int
    let terminated: Int
    let SeriesTitleEn: String
    let SeriesTitleFr: String
    let memberUomCode: Int?
}
