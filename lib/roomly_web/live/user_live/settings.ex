defmodule RoomlyWeb.UserLive.Settings do
  use RoomlyWeb, :live_view
  import RoomlyWeb.ProfileUpload

  on_mount {RoomlyWeb.UserAuth, :require_sudo_mode}

  alias Roomly.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.profile_upload form={@profile_image_form} uploads={@uploads} />

      <div class="divider" />

      <.form
        for={@user_form}
        id="username_form"
        phx-submit="update_username"
        phx-change="validate_username"
      >
        <.input
          field={@user_form[:username]}
          label="Username"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <.input
          field={@user_form[:email]}
          type="email"
          label="Email"
          disabled={true}
        />
        <.button variant="primary" phx-disable-with="Saving...">Save</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          spellcheck="false"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          spellcheck="false"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
          spellcheck="false"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    username_changeset = Accounts.change_user_username(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)
    profile_image_changeset = Accounts.change_user_profile_image(user, %{})

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:page_title, "#{user.username}")
      |> assign(:user_form, to_form(username_changeset))
      |> assign(:profile_image_form, to_form(profile_image_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> allow_upload(
        :profile_image,
        accept: ~w(.png .jpeg .jpg),
        max_entries: 1,
        max_file_size: 10_000_000
      )
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_username", %{"user" => user_params}, socket) do
    user_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_username(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, user_form: user_form)}
  end

  def handle_event("update_username", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_username(user, user_params) do
      {:ok, updated_user} ->
        socket =
          socket
          |> assign(
            current_scope: %{socket.assigns.current_scope | user: updated_user},
            user_form: to_form(Accounts.change_user_username(updated_user, %{}))
          )
          |> put_flash(:info, "Username updated successfully.")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(user_form: to_form(changeset))
          |> put_flash(:error, "Username update failed.")

        {:noreply, socket}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_image, ref)}
  end

  def handle_event("validate_profile_image", _params, socket) do
    changeset =
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile_image(%{})
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, profile_image_form: to_form(changeset))}
  end

  def handle_event("upload", _params, socket) do
    profile_image_paths =
      consume_uploaded_entries(socket, :profile_image, fn meta, entry ->
        dest = Path.join(["priv", "static", "uploads", "#{entry.uuid}-#{entry.client_name}"])
        File.cp!(meta.path, dest)
        url_path = static_path(socket, "/uploads/#{Path.basename(dest)}")
        {:ok, url_path}
      end)

    case Accounts.upload_profile_image(
           socket.assigns.current_scope.user,
           %{"profile_image" => List.first(profile_image_paths)}
         ) do
      {:ok, updated_user} ->
        updated_scope = %{socket.assigns.current_scope | user: updated_user}

        {:noreply,
         socket
         |> assign(:current_scope, updated_scope)
         |> put_flash(:info, "Profile image updated!")}

      {:error, changeset} ->
        {:noreply, assign(socket, profile_image_form: to_form(changeset))}
    end
  end
end
