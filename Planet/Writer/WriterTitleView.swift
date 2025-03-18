//
//  WriterTitleView.swift
//  Planet
//
//  Created by Kai on 1/5/23.
//

import SwiftUI
import WrappingHStack

struct WriterTitleView: View {
    @State private var updatingTags: Bool = false
    @State private var updatingDate: Bool = false
    @State private var titleIsFocused: Bool = false
    @State private var initDate: Date = Date()
    @State private var newTag: String = ""

    var availableTags: [String: Int] = [:]
    @Binding var tags: [String: String]
    @Binding var date: Date
    @Binding var title: String
    @FocusState var focusTitle: Bool

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if #available(macOS 13.0, *) {
                    TextField("Title", text: $title)
                        // .font(.system(size: 15, weight: .regular, design: .default))
                        .font(.custom("Menlo", size: 15.0))
                        .background(Color(NSColor.textBackgroundColor))
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focusTitle, equals: titleIsFocused)
                }
                else {
                    CLTextFieldView(text: $title, placeholder: "Title")
                }
            }
            .frame(height: 34, alignment: .leading)
            .padding(.bottom, 2)
            .padding(.horizontal, 16)

            Spacer(minLength: 8)

            Text("\(date.simpleDateDescription())")
                .foregroundColor(.secondary)
                .background(Color(NSColor.textBackgroundColor))

            Spacer(minLength: 8)

            Button {
                updatingDate.toggle()
            } label: {
                Image(systemName: "calendar.badge.clock")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .popover(isPresented: $updatingDate) {
                VStack(spacing: 10) {
                    Spacer()

                    HStack {
                        HStack {
                            Text("Date")
                            Spacer()
                        }
                        .frame(width: 40)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    .padding(.horizontal, 16)

                    HStack {
                        HStack {
                            Text("Time")
                            Spacer()
                        }
                        .frame(width: 40)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    .padding(.horizontal, 16)

                    Divider()

                    HStack(spacing: 10) {
                        Button {
                            date = Date()
                        } label: {
                            Text("Now")
                        }
                        Spacer()
                        Button {
                            updatingDate = false
                            date = initDate
                        } label: {
                            Text("Cancel")
                        }
                        Button {
                            updatingDate = false
                            // Reset seconds value to zero if set date manually.
                            date = eliminateDateSeconds(fromDate: date)
                        } label: {
                            Text("Set")
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.horizontal, 0)
                .frame(width: 280, height: 124)
            }

            Button {
                updatingTags.toggle()
            } label: {
                Image(systemName: "tag")
                if tags.count > 0 {
                    Text("\(tags.count)")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .popover(isPresented: $updatingTags) {
                tagsView()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .task {
            initDate = date
        }
    }

    private func eliminateDateSeconds(fromDate d: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return calendar.date(from: dateComponents) ?? d
    }

    private func addTag() {
        let aTag = newTag.trim()
        let normalizedTag = aTag.normalizedTag()
        if normalizedTag.count > 0 {
            if tags.keys.contains(aTag) {
                // tag already exists
                return
            }
            tags[normalizedTag] = aTag
            newTag = ""
        }
    }

    @ViewBuilder
    private func tagsView() -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("Tags")
                }
                // Tag capsules
                WrappingHStack(
                    tags.values.sorted(),
                    id: \.self,
                    alignment: .leading,
                    spacing: .constant(2),
                    lineSpacing: 4
                ) { tag in
                    TagView(tag: tag)
                        .onTapGesture {
                            tags.removeValue(forKey: tag.normalizedTag())
                        }
                }
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            HStack(spacing: 10) {
                HStack {
                    Text("Add a Tag")
                    Spacer()
                }

                TextField("", text: $newTag)
                    .onSubmit {
                        addTag()
                    }
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addTag()
                } label: {
                    Text("Add")
                }
            }
            .padding(10)

            if availableTags.count > 0 {
                Divider()

                VStack(spacing: 10) {
                    HStack {
                        Text("Previously Used Tags")
                            .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                    }

                    // Tag capsules
                    WrappingHStack(
                        availableTags.keys.sorted(),
                        id: \.self,
                        alignment: .leading,
                        spacing: .constant(2),
                        lineSpacing: 4
                    ) { tag in
                        TagCountView(tag: tag, count: availableTags[tag] ?? 0)
                            .onTapGesture {
                                let normalizedTag = tag.normalizedTag()
                                tags[normalizedTag] = tag
                            }
                    }
                }
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .frame(width: tagsViewWidth(tagsCount: availableTags.count))
    }

    private func tagsViewWidth(tagsCount: Int) -> CGFloat {
        if (tagsCount > 30) {
            return 380
        } else {
            return 280
        }
    }
}

struct WriterTitleView_Previews: PreviewProvider {
    static var previews: some View {
        WriterTitleView(availableTags: [:], tags: .constant([:]), date: .constant(Date()), title: .constant(""))
    }
}
