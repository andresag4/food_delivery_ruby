class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :edit, :update, :destroy, :generate_pdf]
  skip_before_action :authenticate_user!, :is_authorized, only: [:index_mobile]
  skip_before_filter :verify_authenticity_token, only: [:index_mobile]

  # GET /orders
  # GET /orders.json
  def index
    if current_user.god?
      @search_orders = Order.all.ransack(params[:q])
      @orders = @search_orders.result.paginate(page: params[:page], per_page: 15)
    elsif current_user.has_restaurant_scope?
      @res = current_user.restaurant
      @order_product = OrderProduct.where(product_id: @res.products.ids).pluck(:order_id).uniq
      @search_orders = Order.where(id: @order_product).ransack(params[:q])
      @orders = @search_orders.result.paginate(page: params[:page], per_page: 15)
    else
      @search_orders = current_user.orders.ransack(params[:q])
      @orders = @search_orders.result.paginate(page: params[:page], per_page: 15)
    end
  end

  def index_mobile
    @orders = User.find(params[:id]).orders
    @json = []
    @orders.each do |order|
      @json << {id: order.id, reference_number: order.reference_number,created_at: l(order.created_at, format: :views), street: order.address.get_address}
    end
    render json: @json, status: :ok
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
  end

  # GET /orders/new
  def new
    @order = Order.new
  end

  # GET /orders/1/edit
  def edit
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = current_user.orders.new(order_params)
    @order.reference_number = "#{Time.now.to_i}_#{current_user.id}"

    respond_to do |format|
      if @order.save
        track_actions(@order)
        format.html { redirect_to orders_url, notice: 'Order was successfully created.' }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { render :new }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orders/1
  # PATCH/PUT /orders/1.json
  def update
    extra_parameters = {old_name: @order.name}
    respond_to do |format|
      if @order.update(order_params)
        track_actions(@order, extra_parameters)
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_url, notice: 'Order was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def generate_pdf
    pdf_name = current_user.username + '_' + Time.now.strftime('%Y%d%m_%H%M%S')
    html = render_to_string(action: :generate_pdf, layout: false)
    pdf = WickedPdf.new.pdf_from_string(html)

    send_data(pdf,
              filename: pdf_name,
              disposition: 'attachment')
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_order
    @order = Order.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def order_params
    params.require(:order).permit(:user_id, :reference_number, :address_id)
  end
end
