// assign_transformation_products.h
// C++ implementation of the AssignTransformationProducts algorithm.
// Accepts a flat suspects list (with feature_group pre-joined) and a
// transformation-products input table; returns an expanded output table
// with per-combination cosine-similarity and RT-plausibility metrics.

#ifndef ASSIGN_TRANSFORMATION_PRODUCTS_H
#define ASSIGN_TRANSFORMATION_PRODUCTS_H

#include <string>
#include <vector>

namespace nts::api
{
  struct NTS_SUSPECT_ROW;
  struct NTS_TRANSFORMATION_PRODUCT_ROW;
  struct NTS_TRANSFORMATION_PRODUCTS;
}

namespace nts::assign_transformation_products
{
  nts::api::NTS_TRANSFORMATION_PRODUCTS assign_transformation_products_impl(
      const std::vector<nts::api::NTS_SUSPECT_ROW> &suspects,
      const std::vector<nts::api::NTS_TRANSFORMATION_PRODUCT_ROW> &transformation_products,
      const std::string &chromatographic_phase,
      double mzrMS2);

} // namespace nts::assign_transformation_products

#endif // ASSIGN_TRANSFORMATION_PRODUCTS_H
