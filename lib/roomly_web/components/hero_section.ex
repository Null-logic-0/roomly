defmodule RoomlyWeb.HeroSection do
  use RoomlyWeb, :html

  @doc """
  Renders the main hero section for the Roomly landing page.

  Displays:
  - Title and tagline
  - Description text
  - A primary action button

  Behavior:
  - If `current_scope` is present (user is authenticated), shows a **Create Meeting** button
  - Otherwise, shows a **Log in** button that navigates to the login page

  ## Assigns

    * `:current_scope` - The current user/session scope (nil if unauthenticated)

  """
  attr :current_scope, :any,
    default: nil,
    doc: "Current authenticated scope (e.g., user or session)"

  def hero_section(assigns) do
    ~H"""
    <div class="w-full text-center space-y-4">
      <h1 class="text-3xl font-bold text-primary">Welcome to Roomly</h1>
      <p class="text-5xl font-medium text-base-content leading-normal">
        Hop on a call with everyone, anytime
      </p>
      <p class="text-base-content  text-lg italic text-gray-400 ">
        Video calls and meetings for everyone
      </p>
    </div>

    <div class="flex flex-col gap-4 ">
      <%= if @current_scope do %>
        <.button
          phx-click="create_room"
          class="btn btn-primary py-6 flex items-center justify-between"
        >
          <span class="flex items-center  gap-2">
            <.icon name="hero-plus-solid" class="size-6" /> Create Meeting
          </span>
        </.button>
      <% else %>
        <.button
          phx-click={JS.navigate(~p"/users/log-in")}
          class="btn btn-primary py-6 flex items-center justify-between"
        >
          <span class="flex items-center  gap-2">
            <.icon name="hero-arrow-left-end-on-rectangle" class="size-6" /> Log in
          </span>
        </.button>
      <% end %>
    </div>
    """
  end
end
