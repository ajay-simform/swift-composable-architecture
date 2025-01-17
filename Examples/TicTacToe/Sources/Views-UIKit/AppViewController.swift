import AppCore
import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct UIKitAppView: UIViewControllerRepresentable {
  let store: ComposableStore<AppState, AppAction>

  func makeUIViewController(context: Context) -> AppViewController {
    AppViewController(store: store)
  }

  func updateUIViewController(
    _ uiViewController: AppViewController,
    context: Context
  ) {
    // Nothing to do
  }
}

class AppViewController: UINavigationController {
  let store: ComposableStore<AppState, AppAction>
  private var cancellables: Set<AnyCancellable> = []

  init(store: ComposableStore<AppState, AppAction>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.store
      .scope(state: /AppState.login, action: AppAction.login)
      .ifLet(then: { [weak self] loginStore in
        self?.setViewControllers([LoginViewController(store: loginStore)], animated: false)
      })
      .store(in: &self.cancellables)

    self.store
      .scope(state: /AppState.newGame, action: AppAction.newGame)
      .ifLet(then: { [weak self] newGameStore in
        self?.setViewControllers([NewGameViewController(store: newGameStore)], animated: false)
      })
      .store(in: &self.cancellables)
  }
}
