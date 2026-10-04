  class AvatarInput < SimpleForm::Inputs::FileInput
    def input(wrapper_options = nil)
      template.content_tag(
        :div,
        class: "border border-gray-300 rounded-lg image-picker flex flex-col items-center justify-center",
        data: {
          controller: "image-picker"
        }
      ) do
        template.concat(
          template.content_tag(
            :div,
            class: "flex flex-col items-center justify-center text-center text-mute-700 #{"hidden" if has_image?}",
            data: {
              "image-picker-target": "hint"
            }
          ) do
            template.concat(
              template.content_tag :div, class: "text-sm p-4 pt-6 flex flex-col items-center justify-center mt-1" do
                template.concat upload_svg
                template.concat "Déposer l'image"

                template.concat br
                template.concat "ou"
                template.concat upload_button
              end
            )
            template.concat keep_field

            template.concat input_field(wrapper_options)
          end
        )
        template.concat(
          template.content_tag(:div, class: "flex justify-center mt-4") do
            template.concat(
              template.content_tag(:div, class: "relative") do
                template.concat preview
                template.concat remove
              end
            )
          end
        )
        template.concat input_url_field(wrapper_options)
      end
    end

    def input_url_field(wrapper_options)
      merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)
      @builder.hidden_field(attribute_name, merged_input_options.merge(
        data: {
          "image-picker-target": "urlField"
        }
      ))
    end

    def input_field(wrapper_options)
      merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)
      @builder.file_field("#{attribute_name}_file", merged_input_options.merge(
          {
            class: "opacity-0 inset-0 absolute",
            data: {
              "image-picker-target": "input",
              action: "image-picker#preview"
            }
          }
        )
      )
    end

    def keep_field
      options = {
        value: 1,
        data: {
          "image-picker-target": "keep"
        }
      }
      @builder.hidden_field("#{attribute_name}_keep", options)
    end

    def br
      "<br>".html_safe
    end

    def preview
      %Q(
        <div
          class="preview w-20 h-20 bg-cover bg-center rounded-full border-2 border-gray-200 #{"hidden" unless has_image?}"
          data-image-picker-target="preview"
          #{"style='background-image: url(#{image_url})'" if has_image?}>
        </div>
      ).html_safe
    end

    def image_url
      @builder.object.send(attribute_name)
    end

    def has_image?
      @builder.object.send(attribute_name).present?
    end

    def remove
      %Q(
        <div class="remove absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center cursor-pointer hover:bg-red-600 text-sm #{"hidden" unless has_image?}" data-image-picker-target="remove" data-action="click->image-picker#remove">
          &times;
        </div>
      ).html_safe
    end

    def upload_button
      %Q(
        <div class="button-ghost mt-1">Parcourir vos fichiers</div>
      ).html_safe
    end

    def upload_svg
      %Q(
        <svg width="90" height="40" viewBox="0 0 90 66" fill="#CCC" class="mb-2" xmlns="http://www.w3.org/2000/svg">
          <path d="M45 0C51.9047 0 58.828 2.60948 64.0938 7.875C68.18 11.9613 70.6146 17.074 71.5312 22.375C81.9872 24.0733 90 33.0815 90 44C90 56.1265 80.1265 66 68 66H19C8.5086 66 0 57.4914 0 47C0 36.7863 8.0804 28.5277 18.1875 28.0938C17.895 20.817 20.3931 13.4194 25.9375 7.875C31.1999 2.61244 38.0953 0 45 0ZM45 4C39.1085 4 33.2504 6.2183 28.75 10.7188C23.5485 15.9202 21.3768 22.9839 22.1875 29.75C22.2231 30.0328 22.1979 30.32 22.1134 30.5923C22.029 30.8646 21.8873 31.1157 21.698 31.3287C21.5086 31.5418 21.2758 31.7119 21.0153 31.8277C20.7548 31.9435 20.4726 32.0022 20.1875 32H19C10.6554 32 4 38.6554 4 47C4 55.3446 10.6554 62 19 62H68C77.9647 62 86 53.9647 86 44C86 34.5907 78.8314 26.8955 69.6562 26.0625C69.1992 26.0228 68.7698 25.8273 68.4398 25.5087C68.1099 25.1901 67.8995 24.7678 67.8438 24.3125C67.2668 19.3422 65.0999 14.5373 61.2812 10.7188C56.7838 6.22127 50.8915 4 45 4ZM45 24C45.5349 24.01 46.058 24.2382 46.3438 24.5L57.3438 34.5C58.1657 35.2154 58.2056 36.5644 57.5 37.3438C56.7943 38.1231 55.4326 38.1776 54.6562 37.4688L47 30.5V52C47 53.1046 46.1048 54 45 54C43.8952 54 43 53.1046 43 52V30.5L35.3438 37.4688C34.5674 38.1776 33.2428 38.0879 32.5 37.3438C31.7299 36.5725 31.8737 35.2022 32.6562 34.5L43.6562 24.5C44.0965 24.0977 44.4692 23.9983 45 24Z"/>
        </svg>
      ).html_safe
    end
  end
