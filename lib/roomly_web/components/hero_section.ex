defmodule RoomlyWeb.HeroSection do
  use RoomlyWeb, :html

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
