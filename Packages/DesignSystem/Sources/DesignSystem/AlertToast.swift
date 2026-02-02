//
//  AlertToast.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/7.
//

import SwiftUI

fileprivate let loadingWidth: CGFloat = 150
fileprivate let loadingHeight: CGFloat = 150
fileprivate let textMaxWidth: CGFloat = 300

public enum AlertType: Equatable {
    case systemImage(_ name: String, _ title: String?)
    case loading
}

struct AlertToast: View {
    var type: AlertType
    
    var body: some View {
        switch type {
        case .systemImage(let name, let title):
            HStack {
                Image(systemName: name)
                if let title = title {
                    Text(title)
                        .lineLimit(5)
                        .frame(maxWidth: textMaxWidth)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(10)
        case .loading:
            ProgressView()
                .scaleEffect(2)
                .padding()
                .frame(width: loadingWidth, height: loadingHeight)
                .background(.regularMaterial)
                .cornerRadius(10)
        }
    }
}

struct AlertToastFullscreenModifier: ViewModifier {
    @Binding var isPresenting: Bool
    @State var duration: Double = 2
    let alertType: AlertType

    func body(content: Content) -> some View {
        content
            .background(
                AlertToastPresenter(
                    isPresenting: $isPresenting,
                    duration: duration,
                    alertType: alertType
                )
            )
    }
}

private struct AlertToastPresenter: UIViewControllerRepresentable {
    @Binding var isPresenting: Bool
    let duration: Double
    let alertType: AlertType

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresenting: $isPresenting)
    }

    func makeUIViewController(context: Context) -> PresenterController {
        PresenterController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: PresenterController, context: Context) {
        uiViewController.update(isPresenting: isPresenting, alertType: alertType, duration: duration)
    }

    final class Coordinator {
        private var isPresenting: Binding<Bool>

        init(isPresenting: Binding<Bool>) {
            self.isPresenting = isPresenting
        }

        func dismissWithoutAnimation() {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isPresenting.wrappedValue = false
            }
        }
    }

    final class PresenterController: UIViewController {
        private let coordinator: Coordinator
        private var hostingController: UIHostingController<AlertToastContainer>?
        private var currentAlertType: AlertType?
        private var workItem: DispatchWorkItem?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(isPresenting: Bool, alertType: AlertType, duration: Double) {
            if isPresenting {
                presentIfNeeded(alertType: alertType)
                scheduleDismissIfNeeded(alertType: alertType, duration: duration)
            } else {
                dismissIfNeeded()
            }
        }

        private func presentIfNeeded(alertType: AlertType) {
            if let hostingController = hostingController {
                if currentAlertType != alertType {
                    hostingController.rootView = AlertToastContainer(alertType: alertType)
                    currentAlertType = alertType
                }
                return
            }

            let hostingController = UIHostingController(rootView: AlertToastContainer(alertType: alertType))
            hostingController.view.backgroundColor = .clear
            hostingController.modalPresentationStyle = .overFullScreen
            hostingController.modalTransitionStyle = .crossDissolve
            present(hostingController, animated: false)
            self.hostingController = hostingController
            currentAlertType = alertType
        }

        private func scheduleDismissIfNeeded(alertType: AlertType, duration: Double) {
            guard alertType != .loading, duration > 0 else { return }
            workItem?.cancel()
            let task = DispatchWorkItem { [weak self] in
                self?.coordinator.dismissWithoutAnimation()
                self?.workItem = nil
            }
            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
        }

        private func dismissIfNeeded() {
            guard hostingController != nil else { return }
            workItem?.cancel()
            dismiss(animated: false)
            hostingController = nil
            currentAlertType = nil
        }
    }

    struct AlertToastContainer: View {
        let alertType: AlertType

        var body: some View {
            ZStack {
                Color.clear
                AlertToast(type: alertType)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}

public extension View {
    func toast(isPresenting: Binding<Bool>, duration: Double = 2, alertType: AlertType) -> some View {
        modifier(AlertToastFullscreenModifier(isPresenting: isPresenting, duration: duration, alertType: alertType))
    }
}

#Preview {
    AlertToast(type: .systemImage("xmark.circle", "Error"))
}
