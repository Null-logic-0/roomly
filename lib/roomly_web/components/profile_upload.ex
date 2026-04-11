defmodule RoomlyWeb.ProfileUpload do
  use RoomlyWeb, :html

  @doc """
  Renders a profile image upload form using LiveView uploads.

  Features:
  - Drag & drop upload area
  - File picker input
  - Upload progress tracking
  - Preview of selected images
  - Validation error display
  - Ability to cancel individual uploads

  The form submits an `"upload"` event and validates on `"validate_profile_image"`.

  ## Requirements

  - `@uploads.profile_image` must be configured via `allow_upload/3` in the LiveView
  - The LiveView must handle:
    - `"upload"` event for consuming uploaded entries
    - `"validate_profile_image"` for live validation
    - `"cancel"` event for removing entries

  ## Assigns

    * `:form` - A Phoenix form struct (used for submission context)
    * `:uploads` - Uploads configuration map containing `:profile_image`

  """
  attr :form, :any, required: true, doc: "Phoenix form struct used for submission"
  attr :uploads, :map, required: true, doc: "Uploads map containing :profile_image configuration"

  def profile_upload(assigns) do
    ~H"""
    <.form for={@form} phx-submit="upload" phx-change="validate_profile_image">
      <p class="text-sm text-gray-500 mb-4">
        Upload up to {@uploads.profile_image.max_entries} profile image
        (max {trunc(@uploads.profile_image.max_file_size / 1_000_000)} MB)
      </p>

      <div
        class="border-2 border-dashed border-gray-300  rounded-xl p-8 text-center hover:border-gray-400 transition-colors cursor-pointer"
        phx-drop-target={@uploads.profile_image.ref}
      >
        <.icon name="hero-arrow-up-tray" />
        <p class="text-sm font-medium text-base-content mb-1">Drop your image here</p>
        <p class="text-xs text-gray-400 mb-3">.png, .jpg, .jpeg — max 10 MB</p>

        <.live_file_input
          upload={@uploads.profile_image}
          class="text-xs bg-gray-200 max-w-50 px-6 py-2  mt-4 cursor-pointer text-gray-500"
        />
      </div>

      <p
        :for={err <- upload_errors(@uploads.profile_image)}
        class="mt-2 text-xs text-red-500"
      >
        {Phoenix.Naming.humanize(err)}
      </p>

      <div
        :for={entry <- @uploads.profile_image.entries}
        class="flex items-center gap-3 mt-4 p-3 border border-gray-200 rounded-xl bg-white"
      >
        <.live_img_preview
          entry={entry}
          class="w-12 h-12 rounded-lg object-cover flex-shrink-0"
        />

        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-gray-800 truncate">{entry.client_name}</p>
          <p class="text-xs text-gray-400 mb-2">
            {Float.round(entry.client_size / 1_000, 1)} KB
          </p>
          <div class="h-1.5 rounded-full bg-gray-100 overflow-hidden">
            <div
              class="h-full bg-blue-500 rounded-full transition-all duration-300"
              style={"width: #{entry.progress}%"}
            >
            </div>
          </div>
          <p class="text-xs text-gray-400 mt-1">{entry.progress}%</p>
          <p
            :for={err <- upload_errors(@uploads.profile_image, entry)}
            class="text-xs text-red-500 mt-1"
          >
            {Phoenix.Naming.humanize(err)}
          </p>
        </div>

        <a
          phx-click="cancel"
          phx-value-ref={entry.ref}
          class="text-gray-300 hover:text-gray-500 text-xl leading-none cursor-pointer flex-shrink-0"
        >
          &times;
        </a>
      </div>

      <.button
        phx-disable-with="Uploading..."
        class="btn btn-primary mt-4 w-full"
      >
        Upload
      </.button>
    </.form>
    """
  end
end
