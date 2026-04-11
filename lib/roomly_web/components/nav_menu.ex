defmodule RoomlyWeb.NavMenu do
  use RoomlyWeb, :html

  import RoomlyWeb.ThemeToggle
  import RoomlyWeb.UserDropdown

  @doc """
  Renders the navigation menu with a user dropdown.

  The menu adapts based on authentication state:

  - If `current_scope` is present:
    - Displays the username
    - Shows links to Settings and Log out

  - If `current_scope` is nil:
    - Shows Register and Log in links

  Always includes:
  - Theme toggle control at the bottom of the dropdown

  ## Assigns

    * `:current_scope` - The current user/session scope (nil if unauthenticated)

  """
  attr :current_scope, :any,
    default: nil,
    doc: "Current authenticated scope (e.g., user or session)"

  def nav_menu(assigns) do
    ~H"""
    <nav class="px-4 sm:px-6 lg:px-8 py-4 ">
      <.user_dropdown current_scope={@current_scope}>
        <%= if @current_scope do %>
          <li class="text-center pb-2">
            {@current_scope.user.username}
          </li>
          <hr />

          <li class="pt-2 font-sm font-medium hover:text-primary transition-colors">
            <.link navigate={~p"/users/settings"}>Settings</.link>
          </li>

          <li class="font-sm font-medium hover:text-error transition-colors">
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="font-sm font-medium hover:text-error transition-colors"
            >
              Log out
            </.link>
          </li>
        <% else %>
          <li class="font-sm font-medium hover:text-primary transition-colors">
            <.link navigate={~p"/users/register"}>Register</.link>
          </li>
          <li class="font-sm font-medium hover:text-primary transition-colors">
            <.link navigate={~p"/users/log-in"}>Log in</.link>
          </li>
        <% end %>
        <hr class="mt-4" />
        <li class="w-full">
          <div class="flex items-center justify-center">
            <.theme_toggle />
          </div>
        </li>
      </.user_dropdown>
    </nav>
    """
  end
end
