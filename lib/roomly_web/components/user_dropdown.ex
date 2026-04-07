defmodule RoomlyWeb.UserDropdown do
  use RoomlyWeb, :html

  @doc """
  User dropdown menu with Settings and Log out links.
  """
  attr :current_scope, :any, required: true
  slot :inner_block, required: true

  def user_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end ">
      <div tabindex="0" role="button" class="cursor-pointer">
        <%= if @current_scope && @current_scope.user && @current_scope.user.profile_image do %>
          <img
            src={@current_scope.user.profile_image}
            alt="Profile Image"
            class="w-10 h-10 rounded-full mx-auto object-cover"
          />
        <% else %>
          <.icon name="hero-user-circle" class="size-8 opacity-75 hover:opacity-100" />
        <% end %>
      </div>
      <ul
        tabindex="-1"
        class="menu dropdown-content bg-base-300 rounded-box z-1 w-52 p-2 mt-3 shadow-sm"
      >
        {render_slot(@inner_block)}
      </ul>
    </div>
    """
  end
end
