import Combine
import ComposableArchitecture
import LoginCore
import TicTacToeCommon
import TwoFactorCore
import UIKit

class LoginViewController: UIViewController {
  let store: ComposableStore<LoginState, LoginAction>
  let viewStore: ViewStore<ViewState, ViewAction>
  private var cancellables: Set<AnyCancellable> = []

  struct ViewState: Equatable {
    let alert: AlertState<LoginAction>?
    let email: String?
    let isActivityIndicatorHidden: Bool
    let isEmailTextFieldEnabled: Bool
    let isLoginButtonEnabled: Bool
    let isPasswordTextFieldEnabled: Bool
    let password: String?

    init(state: LoginState) {
      self.alert = state.alert
      self.email = state.email
      self.isActivityIndicatorHidden = !state.isLoginRequestInFlight
      self.isEmailTextFieldEnabled = !state.isLoginRequestInFlight
      self.isLoginButtonEnabled = state.isFormValid && !state.isLoginRequestInFlight
      self.isPasswordTextFieldEnabled = !state.isLoginRequestInFlight
      self.password = state.password
    }
  }

  enum ViewAction {
    case alertDismissed
    case emailChanged(String?)
    case loginButtonTapped
    case passwordChanged(String?)
    case twoFactorDismissed
  }

  init(store: ComposableStore<LoginState, LoginAction>) {
    self.store = store
    self.viewStore = ViewStore(store.scope(state: ViewState.init, action: LoginAction.init))
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "Login"
    self.view.backgroundColor = .systemBackground

    let disclaimerLabel = UILabel()
    disclaimerLabel.text = """
      To login use any email and "password" for the password. If your email contains the \
      characters "2fa" you will be taken to a two-factor flow, and on that screen you can use \
      "1234" for the code.
      """
    disclaimerLabel.textAlignment = .left
    disclaimerLabel.numberOfLines = 0

    let divider = UIView()
    divider.backgroundColor = .gray

    let titleLabel = UILabel()
    titleLabel.text = "Please log in to play TicTacToe!"
    titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
    titleLabel.numberOfLines = 0

    let emailTextField = UITextField()
    emailTextField.placeholder = "email@address.com"
    emailTextField.borderStyle = .roundedRect
    emailTextField.autocapitalizationType = .none
    emailTextField.addTarget(
      self, action: #selector(emailTextFieldChanged(sender:)), for: .editingChanged)

    let passwordTextField = UITextField()
    passwordTextField.placeholder = "**********"
    passwordTextField.borderStyle = .roundedRect
    passwordTextField.addTarget(
      self, action: #selector(passwordTextFieldChanged(sender:)), for: .editingChanged)
    passwordTextField.isSecureTextEntry = true

    let loginButton = UIButton(type: .system)
    loginButton.setTitle("Login", for: .normal)
    loginButton.addTarget(self, action: #selector(loginButtonTapped(sender:)), for: .touchUpInside)

    let activityIndicator = UIActivityIndicatorView(style: .large)
    activityIndicator.startAnimating()

    let rootStackView = UIStackView(arrangedSubviews: [
      disclaimerLabel,
      divider,
      titleLabel,
      emailTextField,
      passwordTextField,
      loginButton,
      activityIndicator,
    ])
    rootStackView.isLayoutMarginsRelativeArrangement = true
    rootStackView.layoutMargins = .init(top: 0, left: 32, bottom: 0, right: 32)
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    rootStackView.axis = .vertical
    rootStackView.spacing = 24

    self.view.addSubview(rootStackView)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
      divider.heightAnchor.constraint(equalToConstant: 1),
    ])

    self.viewStore.publisher.isLoginButtonEnabled
      .assign(to: \.isEnabled, on: loginButton)
      .store(in: &self.cancellables)

    self.viewStore.publisher.email
      .assign(to: \.text, on: emailTextField)
      .store(in: &self.cancellables)

    self.viewStore.publisher.isEmailTextFieldEnabled
      .assign(to: \.isEnabled, on: emailTextField)
      .store(in: &self.cancellables)

    self.viewStore.publisher.password
      .assign(to: \.text, on: passwordTextField)
      .store(in: &self.cancellables)

    self.viewStore.publisher.isPasswordTextFieldEnabled
      .assign(to: \.isEnabled, on: passwordTextField)
      .store(in: &self.cancellables)

    self.viewStore.publisher.isActivityIndicatorHidden
      .assign(to: \.isHidden, on: activityIndicator)
      .store(in: &self.cancellables)

    self.viewStore.publisher.alert
      .sink { [weak self] alert in
        guard let self = self else { return }
        guard let alert = alert else { return }

        let alertController = UIAlertController(
          title: String(state: alert.title), message: nil, preferredStyle: .alert)
        alertController.addAction(
          UIAlertAction(
            title: "Ok", style: .default,
            handler: { _ in
              self.viewStore.send(.alertDismissed)
            }))
        self.present(alertController, animated: true, completion: nil)
      }
      .store(in: &self.cancellables)

    self.store
      .scope(state: \.twoFactor, action: LoginAction.twoFactor)
      .ifLet(
        then: { [weak self] twoFactorStore in
          self?.navigationController?.pushViewController(
            TwoFactorViewController(store: twoFactorStore),
            animated: true
          )
        },
        else: { [weak self] in
          guard let self = self else { return }
          self.navigationController?.popToViewController(self, animated: true)
        }
      )
      .store(in: &self.cancellables)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if !self.isMovingToParent {
      self.viewStore.send(.twoFactorDismissed)
    }
  }

  @objc private func loginButtonTapped(sender: UIButton) {
    self.viewStore.send(.loginButtonTapped)
  }

  @objc private func emailTextFieldChanged(sender: UITextField) {
    self.viewStore.send(.emailChanged(sender.text))
  }

  @objc private func passwordTextFieldChanged(sender: UITextField) {
    self.viewStore.send(.passwordChanged(sender.text))
  }
}

extension LoginAction {
  init(action: LoginViewController.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case let .emailChanged(email):
      self = .emailChanged(email ?? "")
    case .loginButtonTapped:
      self = .loginButtonTapped
    case let .passwordChanged(password):
      self = .passwordChanged(password ?? "")
    case .twoFactorDismissed:
      self = .twoFactorDismissed
    }
  }
}
