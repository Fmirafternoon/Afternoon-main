
class SwitchInput < SimpleForm::Inputs::BooleanInput
  def input(wrapper_options = nil)
    # add the class to the wrapper
    wrapper_options = merge_wrapper_options(wrapper_options || {}, class: "relative inline-flex items-center cursor-pointer")
    # add the class to the input
    input_html_classes.unshift("sr-only peer")
    # add the class to the label
    @builder.label(attribute_name, class: "relative flex items-center") do
      @builder.check_box(attribute_name, input_html_options) +
        template.content_tag(:div, "", class: "absolute left-0.5 top-0.5 size-5 bg-white rounded-full shadow-sm transform transition peer-checked:translate-x-5") +
        template.content_tag(:div, "", class: "w-11 h-6 bg-mute-400 peer-checked:bg-success-500 rounded-full border border-mute-500 peer-checked:border-success-600 transition-colors duration-200 ease-in-out")
    end
  end
end
